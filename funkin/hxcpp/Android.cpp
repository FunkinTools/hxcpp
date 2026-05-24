#include <hxcpp.h>
#include <hx/CFFI.h>
#include <hx/Macros.h>

#include <android/log.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/native_activity.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <android/configuration.h>
#include <android/looper.h>

#include <jni.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

#define FUNKIN_LOG_TAG        "FunkinHxcpp"
#define FUNKIN_LOG_INFO(...)  __android_log_print(ANDROID_LOG_INFO,  FUNKIN_LOG_TAG, __VA_ARGS__)
#define FUNKIN_LOG_WARN(...)  __android_log_print(ANDROID_LOG_WARN,  FUNKIN_LOG_TAG, __VA_ARGS__)
#define FUNKIN_LOG_ERROR(...) __android_log_print(ANDROID_LOG_ERROR, FUNKIN_LOG_TAG, __VA_ARGS__)

static JavaVM          *sJavaVM         = nullptr;
static jobject          sActivityObject = nullptr;
static jobject          sAssetManager   = nullptr;
static AAssetManager   *sNativeAssetMgr = nullptr;
static ANativeWindow   *sNativeWindow   = nullptr;
static pthread_mutex_t  sStateMutex     = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t  sWindowMutex    = PTHREAD_MUTEX_INITIALIZER;

static int              sDisplayWidth   = 0;
static int              sDisplayHeight  = 0;
static float            sDisplayDensity = 1.0f;
static bool             sHasFocus       = false;
static bool             sSurfaceReady   = false;
static bool             sAppRunning     = false;

static JNIEnv *getJNIEnv()
{
   if (!sJavaVM) return nullptr;

   JNIEnv *env    = nullptr;
   jint    result = sJavaVM->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6);

   if (result == JNI_EDETACHED)
   {
      JavaVMAttachArgs args = { JNI_VERSION_1_6, FUNKIN_LOG_TAG, nullptr };
      if (sJavaVM->AttachCurrentThread(&env, &args) != JNI_OK)
         return nullptr;
   }
   else if (result != JNI_OK)
      return nullptr;

   return env;
}

static void detachCurrentThread()
{
   if (sJavaVM)
      sJavaVM->DetachCurrentThread();
}

static jclass findClass(JNIEnv *env, const char *name)
{
   jclass cls = env->FindClass(name);
   if (!cls) env->ExceptionClear();
   return cls;
}

static jmethodID findMethod(JNIEnv *env, jclass cls, const char *name, const char *sig)
{
   jmethodID mid = env->GetMethodID(cls, name, sig);
   if (!mid) env->ExceptionClear();
   return mid;
}

static jmethodID findStaticMethod(JNIEnv *env, jclass cls, const char *name, const char *sig)
{
   jmethodID mid = env->GetStaticMethodID(cls, name, sig);
   if (!mid) env->ExceptionClear();
   return mid;
}

static std::string jstringToStd(JNIEnv *env, jstring str)
{
   if (!str) return "";
   const char *raw    = env->GetStringUTFChars(str, nullptr);
   std::string result = raw ? raw : "";
   env->ReleaseStringUTFChars(str, raw);
   return result;
}

static jstring stdToJstring(JNIEnv *env, const std::string &str)
{
   return env->NewStringUTF(str.c_str());
}

static void lockState()  { pthread_mutex_lock(&sStateMutex);   }
static void unlockState(){ pthread_mutex_unlock(&sStateMutex); }
static void lockWindow() { pthread_mutex_lock(&sWindowMutex);  }
static void unlockWindow(){ pthread_mutex_unlock(&sWindowMutex); }

static bool initAssetManager(JNIEnv *env, jobject activity)
{
   jclass    cls = findClass(env, "android/app/Activity");
   jmethodID mid = findMethod(env, cls, "getAssets", "()Landroid/content/res/AssetManager;");

   if (!cls || !mid) return false;

   jobject localAssets = env->CallObjectMethod(activity, mid);
   if (!localAssets) return false;

   if (sAssetManager)
      env->DeleteGlobalRef(sAssetManager);

   sAssetManager   = env->NewGlobalRef(localAssets);
   sNativeAssetMgr = AAssetManager_fromJava(env, sAssetManager);
   env->DeleteLocalRef(localAssets);

   return sNativeAssetMgr != nullptr;
}

static bool initDisplay(JNIEnv *env, jobject activity)
{
   jclass    cls        = findClass(env, "android/app/Activity");
   jmethodID getWindow  = findMethod(env, cls, "getWindow", "()Landroid/view/Window;");

   if (!cls || !getWindow) return false;

   jobject window = env->CallObjectMethod(activity, getWindow);
   if (!window) return false;

   jclass    windowCls    = findClass(env, "android/view/Window");
   jmethodID getDecorView = findMethod(env, windowCls, "getDecorView", "()Landroid/view/View;");

   if (!windowCls || !getDecorView)
   {
      env->DeleteLocalRef(window);
      return false;
   }

   jobject decorView = env->CallObjectMethod(window, getDecorView);
   env->DeleteLocalRef(window);
   if (!decorView) return false;

   jclass    viewCls  = findClass(env, "android/view/View");
   jmethodID getWidth = findMethod(env, viewCls, "getWidth",  "()I");
   jmethodID getHeight= findMethod(env, viewCls, "getHeight", "()I");

   if (getWidth && getHeight)
   {
      sDisplayWidth  = (int)env->CallIntMethod(decorView, getWidth);
      sDisplayHeight = (int)env->CallIntMethod(decorView, getHeight);
   }

   env->DeleteLocalRef(decorView);
   return true;
}

static float resolveDisplayDensity(JNIEnv *env, jobject activity)
{
   jclass    cls       = findClass(env, "android/app/Activity");
   jmethodID getRes    = findMethod(env, cls, "getResources", "()Landroid/content/res/Resources;");
   if (!cls || !getRes) return 1.0f;

   jobject   resources = env->CallObjectMethod(activity, getRes);
   if (!resources) return 1.0f;

   jclass    resCls    = findClass(env, "android/content/res/Resources");
   jmethodID getDM     = findMethod(env, resCls, "getDisplayMetrics", "()Landroid/util/DisplayMetrics;");
   if (!resCls || !getDM)
   {
      env->DeleteLocalRef(resources);
      return 1.0f;
   }

   jobject   dm        = env->CallObjectMethod(resources, getDM);
   env->DeleteLocalRef(resources);
   if (!dm) return 1.0f;

   jclass    dmCls     = findClass(env, "android/util/DisplayMetrics");
   jfieldID  densityFd = env->GetFieldID(dmCls, "density", "F");
   float     density   = densityFd ? env->GetFloatField(dm, densityFd) : 1.0f;

   env->DeleteLocalRef(dm);
   return density;
}

static AAsset *openAsset(const char *path, int mode)
{
   if (!sNativeAssetMgr) return nullptr;
   return AAssetManager_open(sNativeAssetMgr, path, mode);
}

static int readAsset(AAsset *asset, void *buffer, size_t size)
{
   if (!asset) return -1;
   return AAsset_read(asset, buffer, size);
}

static off_t assetLength(AAsset *asset)
{
   if (!asset) return 0;
   return AAsset_getLength(asset);
}

static void closeAsset(AAsset *asset)
{
   if (asset)
      AAsset_close(asset);
}

static bool assetExists(const char *path)
{
   AAsset *asset = openAsset(path, AASSET_MODE_UNKNOWN);
   if (!asset) return false;
   AAsset_close(asset);
   return true;
}

static void setNativeWindow(ANativeWindow *window)
{
   lockWindow();
   if (sNativeWindow)
      ANativeWindow_release(sNativeWindow);
   sNativeWindow = window;
   if (sNativeWindow)
      ANativeWindow_acquire(sNativeWindow);
   sSurfaceReady = sNativeWindow != nullptr;
   unlockWindow();
}

static void clearNativeWindow()
{
   lockWindow();
   if (sNativeWindow)
   {
      ANativeWindow_release(sNativeWindow);
      sNativeWindow = nullptr;
   }
   sSurfaceReady = false;
   unlockWindow();
}

static int getNativeWindowWidth()
{
   if (!sNativeWindow) return sDisplayWidth;
   return ANativeWindow_getWidth(sNativeWindow);
}

static int getNativeWindowHeight()
{
   if (!sNativeWindow) return sDisplayHeight;
   return ANativeWindow_getHeight(sNativeWindow);
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *)
{
   sJavaVM = vm;

   JNIEnv *env = getJNIEnv();
   if (!env) return JNI_ERR;

   FUNKIN_LOG_INFO("JNI_OnLoad — FunkinHxcpp initialized.");
   return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *, void *)
{
   JNIEnv *env = getJNIEnv();

   if (env)
   {
      if (sAssetManager)
      {
         env->DeleteGlobalRef(sAssetManager);
         sAssetManager = nullptr;
      }
      if (sActivityObject)
      {
         env->DeleteGlobalRef(sActivityObject);
         sActivityObject = nullptr;
      }
   }

   clearNativeWindow();
   sNativeAssetMgr = nullptr;
   sJavaVM         = nullptr;
}

extern "C"
{

JNIEXPORT void JNICALL Java_funkin_hxcpp_Android_nativeInit(JNIEnv *env, jobject, jobject activity)
{
   lockState();

   if (sActivityObject)
      env->DeleteGlobalRef(sActivityObject);

   sActivityObject = env->NewGlobalRef(activity);
   sAppRunning     = true;

   initAssetManager(env, activity);
   initDisplay(env, activity);
   sDisplayDensity = resolveDisplayDensity(env, activity);

   unlockState();
}

JNIEXPORT void JNICALL Java_funkin_hxcpp_Android_nativeDestroy(JNIEnv *env, jobject)
{
   lockState();

   sAppRunning = false;

   if (sActivityObject)
   {
      env->DeleteGlobalRef(sActivityObject);
      sActivityObject = nullptr;
   }

   clearNativeWindow();

   unlockState();
}

JNIEXPORT void JNICALL Java_funkin_hxcpp_Android_nativeSurfaceCreated(JNIEnv *env, jobject, jobject surface)
{
   ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
   setNativeWindow(window);
   if (window) ANativeWindow_release(window);
}

JNIEXPORT void JNICALL Java_funkin_hxcpp_Android_nativeSurfaceDestroyed(JNIEnv *, jobject)
{
   clearNativeWindow();
}

JNIEXPORT void JNICALL Java_funkin_hxcpp_Android_nativeSurfaceChanged(JNIEnv *, jobject, jint width, jint height)
{
   lockState();
   sDisplayWidth  = (int)width;
   sDisplayHeight = (int)height;
   unlockState();
}

JNIEXPORT void JNICALL Java_funkin_hxcpp_Android_nativeFocusChanged(JNIEnv *, jobject, jboolean focused)
{
   lockState();
   sHasFocus = (bool)focused;
   unlockState();
}

JNIEXPORT jint JNICALL Java_funkin_hxcpp_Android_nativeGetWidth(JNIEnv *, jobject)
{
   return (jint)getNativeWindowWidth();
}

JNIEXPORT jint JNICALL Java_funkin_hxcpp_Android_nativeGetHeight(JNIEnv *, jobject)
{
   return (jint)getNativeWindowHeight();
}

JNIEXPORT jfloat JNICALL Java_funkin_hxcpp_Android_nativeGetDensity(JNIEnv *, jobject)
{
   return (jfloat)sDisplayDensity;
}

JNIEXPORT jboolean JNICALL Java_funkin_hxcpp_Android_nativeAssetExists(JNIEnv *env, jobject, jstring path)
{
   std::string p = jstringToStd(env, path);
   return (jboolean)assetExists(p.c_str());
}

JNIEXPORT jbyteArray JNICALL Java_funkin_hxcpp_Android_nativeReadAsset(JNIEnv *env, jobject, jstring path)
{
   std::string p     = jstringToStd(env, path);
   AAsset    *asset  = openAsset(p.c_str(), AASSET_MODE_BUFFER);
   if (!asset) return nullptr;

   off_t      length = assetLength(asset);
   jbyteArray result = env->NewByteArray((jsize)length);

   if (result)
   {
      jbyte *buf = env->GetByteArrayElements(result, nullptr);
      readAsset(asset, buf, (size_t)length);
      env->ReleaseByteArrayElements(result, buf, 0);
   }

   closeAsset(asset);
   return result;
}

JNIEXPORT jboolean JNICALL Java_funkin_hxcpp_Android_nativeIsRunning(JNIEnv *, jobject)
{
   return (jboolean)sAppRunning;
}

JNIEXPORT jboolean JNICALL Java_funkin_hxcpp_Android_nativeHasFocus(JNIEnv *, jobject)
{
   return (jboolean)sHasFocus;
}

JNIEXPORT jboolean JNICALL Java_funkin_hxcpp_Android_nativeSurfaceReady(JNIEnv *, jobject)
{
   return (jboolean)sSurfaceReady;
}

}
