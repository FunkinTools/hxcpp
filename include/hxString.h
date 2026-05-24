#ifndef HX_STRING_H
#define HX_STRING_H

#ifndef HXCPP_H
   #error "Please include hxcpp.h, not hx/String.h directly"
#endif

#include <hx/StringAlloc.h>

#ifdef __OBJC__
   #import <Foundation/Foundation.h>
#endif

class HXCPP_EXTERN_CLASS_ATTRIBUTES String
{
   friend class StringOffset;

public:

   void *operator new(size_t inSize);
   inline void *operator new(size_t, void *ptr) noexcept { return ptr; }
   inline void  operator delete(void *) noexcept {}

   inline String() noexcept : length(0), __s(nullptr) {}
   inline String(const null &) noexcept : length(0), __s(nullptr) {}
   inline String(const ::String &inRHS) noexcept : __s(inRHS.__s), length(inRHS.length) {}

   inline String(const char *inPtr, int inLen) noexcept : __s(inPtr), length(inLen) {}
   #ifdef HX_SMART_STRINGS
   inline String(const char16_t *inPtr, int inLen) noexcept : __w(inPtr), length(inLen) {}
   #endif

   inline String(const wchar_t  *inPtr) { *this = create(inPtr); }
   inline String(const char16_t *inPtr) { *this = create(inPtr); }
   inline String(const char     *inPtr) { *this = create(inPtr); }

   static String create(const wchar_t  *inPtr, int inLen = -1);
   static String create(const char16_t *inPtr, int inLen = -1);
   static String create(const char     *inPtr, int inLen = -1);

   static String create(const ::cpp::marshal::View<char>      &buffer);
   static String create(const ::cpp::marshal::View<char16_t>  &buffer);

   static ::String   createPermanent(const char *inUtf8, int inLen);
   const ::String   &makePermanent() const;
   hx::Object       *makePermanentObject() const;

   ::String &dup();

   #ifdef __OBJC__
   inline String(NSString *inString)
   {
      if (inString)
         *this = String([inString UTF8String]);
      else
      {
         length = 0;
         __s = nullptr;
      }
   }
   inline operator NSString *() const
   {
      hx::strbuf buf;
      return [[NSString alloc] initWithUTF8String:utf8_str(&buf)];
   }
   #endif

   #if defined(HX_WINRT) && defined(__cplusplus_winrt)
   inline String(Platform::String ^inString)       { *this = String(inString->Data()); }
   inline String(Platform::StringReference inString) { *this = String(inString.Data()); }
   #endif

   explicit String(const bool         &inRHS);
   String(const int                   &inRHS);
   String(const unsigned int          &inRHS);
   String(const short                 &inRHS) { fromInt(inRHS); }
   String(const unsigned short        &inRHS) { fromInt(inRHS); }
   String(const signed char           &inRHS) { fromInt(inRHS); }
   String(const unsigned char         &inRHS) { fromInt(inRHS); }
   String(const double                &inRHS);
   String(const float                 &inRHS);
   String(const cpp::CppInt32__       &inRHS);
   String(const cpp::Int64            &inRHS);
   String(const cpp::UInt64           &inRHS);
   String(hx::Null<::String>    inRHS) : __s(inRHS.value.__s), length(inRHS.value.length) {}
   inline String(const ::cpp::Variant &inRHS) { *this = inRHS.asString(); }

   template<typename T>
   inline String(const ::cpp::Pointer<T> &inRHS) { fromPointer(inRHS.ptr); }
   template<typename T>
   inline String(const hx::Native<T>     &n)     { fromPointer(n.ptr); }
   template<typename T, typename S>
   explicit inline String(const cpp::Struct<T, S>       &inRHS);
   template<typename OBJ>
   explicit inline String(const hx::ObjectPtr<OBJ>      &inRHS);

   String(const Dynamic &inRHS);

   static String emptyString;
   static void __boot();

   hx::Object *__ToObject() const;

   void fromInt(int inI);
   void fromPointer(const void *p);

   inline ::String &operator=(const ::String &inRHS)
   {
      length = inRHS.length;
      __s    = inRHS.__s;
      return *this;
   }

   ::String Default(const ::String &inDef) const { return __s ? *this : inDef; }
   ::String toString() const { return *this; }

   ::String __URLEncode() const;
   ::String __URLDecode() const;

   ::String toUpperCase() const;
   ::String toLowerCase() const;
   ::String charAt(int inPos) const;
   Dynamic  charCodeAt(int inPos) const;
   int      indexOf(const ::String &inValue, Dynamic inStart) const;
   int      lastIndexOf(const ::String &inValue, Dynamic inStart) const;
   Array<String> split(const ::String &inDelimiter) const;
   ::String substr(int inPos, Dynamic inLen) const;
   ::String substring(int inStartIndex, Dynamic inEndIndex) const;

   inline const char *&raw_ref()                                          { return __s; }
   inline const char  *raw_ptr() const                                    { return __s; }
   const char    *utf8_str(hx::IStringAlloc *inBuffer = nullptr, bool throwInvalid = true, int *byteLength = nullptr) const;
   const char    *ascii_substr(hx::IStringAlloc *inBuffer, int start, int length) const;
   inline const char *c_str()   const                                     { return utf8_str(); }
   inline const char *out_str(hx::IStringAlloc *inBuffer = nullptr) const { return utf8_str(inBuffer, false); }
   const wchar_t  *wchar_str(hx::IStringAlloc *inBuffer = nullptr) const;
   const char16_t *wc_str(hx::IStringAlloc *inBuffer = nullptr, int *outCharLength = nullptr) const;

   bool wc_str(::cpp::marshal::View<char16_t> buffer, int *outCharLength = nullptr) const;
   bool utf8_str(::cpp::marshal::View<char>   buffer, int *outByteLength  = nullptr) const;

   const char    *__CStr()  const { return utf8_str(); }
   const wchar_t *__WCStr() const { return wchar_str(nullptr); }
   inline operator const char *() { return utf8_str(); }

   #ifdef HX_SMART_STRINGS
   inline const char16_t *raw_wptr() const { return __w; }
   #endif

   inline bool isUTF16Encoded() const
   {
      #ifdef HX_SMART_STRINGS
      return __w && ((unsigned int *)__w)[-1] & HX_GC_STRING_CHAR16_T;
      #else
      return false;
      #endif
   }

   inline bool isAsciiEncoded() const
   {
      #ifdef HX_SMART_STRINGS
      return !__w || !(((unsigned int *)__w)[-1] & HX_GC_STRING_CHAR16_T);
      #else
      return true;
      #endif
   }

   inline bool isAsciiEncodedQ() const
   {
      #ifdef HX_SMART_STRINGS
      return !(((unsigned int *)__w)[-1] & HX_GC_STRING_CHAR16_T);
      #else
      return true;
      #endif
   }

   static ::String fromCharCode(int inCode);

   inline bool operator==(const null &) const { return __s == nullptr; }
   inline bool operator!=(const null &) const { return __s != nullptr; }

   inline int getChar(int index) const
   {
      #ifdef HX_SMART_STRINGS
      if (isUTF16Encoded()) return __w[index];
      #endif
      return __s[index];
   }

   inline unsigned int hash() const
   {
      if (!__s) return 0;
      if (__s[HX_GC_STRING_HASH_OFFSET] & HX_GC_STRING_HASH_BIT)
      {
         if (__s[HX_GC_CONST_ALLOC_MARK_OFFSET] & HX_GC_CONST_ALLOC_MARK_BIT)
         {
            #ifdef EMSCRIPTEN
            return ((emscripten_align1_int *)__s)[-2];
            #else
            return ((unsigned int *)__s)[-2];
            #endif
         }
         #ifdef EMSCRIPTEN
         return *((emscripten_align1_int *)(__s + length + 1));
         #else
         return *((unsigned int *)(__s + length + 1));
         #endif
      }
      return calcHash();
   }

   unsigned int calcHash() const;
   unsigned int calcSubHash(int start, int length) const;

   #ifdef HX_SMART_STRINGS
   int compare(const ::String &inRHS) const;
   #else
   inline int compare(const ::String &inRHS) const
   {
      const char *r = inRHS.__s;
      if (__s == r)  return inRHS.length - length;
      if (!__s)      return -1;
      if (!r)        return  1;
      return strcmp(__s, r);
   }
   #endif

   ::String &operator+=(const ::String &inRHS);
   ::String  operator+(const ::String      &inRHS) const;
   ::String  operator+(const int           &inRHS) const { return *this + ::String(inRHS); }
   ::String  operator+(const bool          &inRHS) const { return *this + ::String(inRHS); }
   ::String  operator+(const double        &inRHS) const { return *this + ::String(inRHS); }
   ::String  operator+(const float         &inRHS) const { return *this + ::String(inRHS); }
   ::String  operator+(const null          &)      const { return *this + HX_CSTRING("null"); }
   ::String  operator+(const cpp::CppInt32__ &inRHS) const { return *this + ::String(inRHS); }
   ::String  operator+(const cpp::Variant  &inRHS) const { return *this + inRHS.asString(); }

   template<typename T>
   inline ::String operator+(const hx::ObjectPtr<T> &inRHS) const
   {
      return *this + (inRHS.mPtr ? const_cast<hx::ObjectPtr<T> &>(inRHS)->toString() : HX_CSTRING("null"));
   }

   #ifdef HX_SMART_STRINGS
   bool eq(const ::String &inRHS) const;
   #else
   inline bool eq(const ::String &inRHS) const
   {
      return length == inRHS.length && !memcmp(__s, inRHS.__s, length);
   }
   #endif

   inline bool operator==(const ::String &inRHS) const
   {
      if (!inRHS.__s) return !__s;
      if (!__s)       return false;
      return eq(inRHS);
   }
   inline bool operator!=(const ::String &inRHS) const
   {
      if (!inRHS.__s) return __s != nullptr;
      if (!__s)       return true;
      return !eq(inRHS);
   }

   inline bool operator< (const ::String &inRHS) const { return compare(inRHS) <  0; }
   inline bool operator<=(const ::String &inRHS) const { return compare(inRHS) <= 0; }
   inline bool operator> (const ::String &inRHS) const { return compare(inRHS) >  0; }
   inline bool operator>=(const ::String &inRHS) const { return compare(inRHS) >= 0; }

   inline bool operator< (const Dynamic &inRHS) const { return compare(inRHS) <  0; }
   inline bool operator<=(const Dynamic &inRHS) const { return compare(inRHS) <= 0; }
   inline bool operator> (const Dynamic &inRHS) const { return compare(inRHS) >  0; }
   inline bool operator>=(const Dynamic &inRHS) const { return compare(inRHS) >= 0; }

   inline int cca(int inPos) const
   {
      if (inPos >= length || inPos < 0) return 0;
      #ifdef HX_SMART_STRINGS
      if (isUTF16Encoded()) return __w[inPos];
      #endif
      return ((unsigned char *)__s)[inPos];
   }

   inline Dynamic iterator();
   inline Dynamic keyValueIterator();

   static char16_t *allocChar16Ptr(int len);

   hx::Val __Field(const ::String &inString, hx::PropertyAccess inCallProp);

#if (HXCPP_API_LEVEL >= 500)
   static ::hx::Callable<::String(int)>                      fromCharCode_dyn();
   ::hx::Callable<::String(int)>                             charAt_dyn();
   ::hx::Callable<::Dynamic(int)>                            charCodeAt_dyn();
   ::hx::Callable<int(::String, ::Dynamic)>                  indexOf_dyn();
   ::hx::Callable<int(::String, ::Dynamic)>                  lastIndexOf_dyn();
   ::hx::Callable<::Array<::String>(::String)>               split_dyn();
   ::hx::Callable<::String(int, ::Dynamic)>                  substr_dyn();
   ::hx::Callable<::String(int, ::Dynamic)>                  substring_dyn();
   ::hx::Callable<::String()>                                toLowerCase_dyn();
   ::hx::Callable<::String()>                                toString_dyn();
   ::hx::Callable<::String()>                                toUpperCase_dyn();
#else
   static Dynamic fromCharCode_dyn();
   Dynamic charAt_dyn();
   Dynamic charCodeAt_dyn();
   Dynamic indexOf_dyn();
   Dynamic lastIndexOf_dyn();
   Dynamic split_dyn();
   Dynamic substr_dyn();
   Dynamic substring_dyn();
   Dynamic toLowerCase_dyn();
   Dynamic toString_dyn();
   Dynamic toUpperCase_dyn();
#endif

   int length;

   #ifdef HX_SMART_STRINGS
   union {
      const char     *__s;
      const char16_t *__w;
   };
   #else
   const char *__s;
   #endif
};

class StringOffset
{
public:
   enum { Ptr = offsetof(String, __s) };
};

inline HXCPP_EXTERN_CLASS_ATTRIBUTES String _hx_string_create(const char *str, int len)
{
   return String::create(str, len);
}

inline int HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_string_compare(String inString0, String inString1)
{
   return inString0.compare(inString1);
}

String HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_utf8_to_utf16(const unsigned char *ptr, int inUtf8Len, bool addHash);
int    HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_utf8_char_code_at(String inString, int inIndex);
int    HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_utf8_length(String inString);
bool   HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_utf8_is_valid(String inString);
String HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_utf8_sub(String inString0, int inStart, int inLen);
int    HXCPP_EXTERN_CLASS_ATTRIBUTES _hx_utf8_decode_advance(char *&ioPtr);

#endif
