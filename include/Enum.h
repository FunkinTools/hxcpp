#ifndef HX_ENUM_H
#define HX_ENUM_H

#ifndef HXCPP_H
   #error "Please include hxcpp.h, not hx/Enum.h directly"
#endif

typedef hx::Class Enum;

namespace hx
{

class HXCPP_EXTERN_CLASS_ATTRIBUTES EnumBase_obj : public hx::Object
{
   typedef hx::Object      super;
   typedef EnumBase_obj    OBJ_;

protected:
   String   _hx_tag;
   int      mFixedFields;

   #ifdef HXCPP_SCRIPTABLE
   struct CppiaClassInfo *classInfo;
   #endif

public:
   HX_IS_INSTANCE_OF enum { _hx_ClassId = hx::clsIdEnum };

   int index;

   inline void *operator new(size_t inSize, int inExtra = 0) noexcept
   {
      return hx::Object::operator new(inSize + inExtra, true, 0);
   }
   inline void operator delete(void *, int)             noexcept {}
   inline void operator delete(void *, size_t)          noexcept {}
   inline void operator delete(void *, size_t, int)     noexcept {}

   HX_DO_ENUM_RTTI_INTERNAL;

   static hx::ObjectPtr<hx::Class_obj> &__SGetClass();

   EnumBase_obj() noexcept : index(-1), mFixedFields(0) {}
   explicit EnumBase_obj(const null &) noexcept : index(-1), mFixedFields(0) {}

   int    __GetType()  const override { return vtEnum; }
   String toString()   const;
   String GetEnumName()const override { return HX_CSTRING("Enum"); }

   static Dynamic  __CreateEmpty();
   static Dynamic  __Create(DynamicArray inArgs);
   static void     __boot();

   void __Mark(hx::MarkContext *__inCtx) override;

   #ifdef HXCPP_VISIT_ALLOCS
   void __Visit(hx::VisitContext *__inCtx) override;
   #endif

   static hx::ObjectPtr<EnumBase_obj> Resolve(const String &inName);

   inline static bool __GetStatic(const ::String &, Dynamic &, hx::PropertyAccess) noexcept
   {
      return false;
   }

   inline cpp::Variant       *_hx_getFixed()       noexcept { return reinterpret_cast<cpp::Variant *>(this + 1); }
   inline const cpp::Variant *_hx_getFixed() const noexcept { return reinterpret_cast<const cpp::Variant *>(this + 1); }

   inline void _hx_setIdentity(const String &inTag, int inIndex, int inFixedFields) noexcept
   {
      _hx_tag      = inTag;
      HX_OBJ_WB_GET(this, _hx_tag.__s);
      index        = inIndex;
      mFixedFields = inFixedFields;
   }

   template<typename T>
   inline EnumBase_obj *_hx_init(int inIndex, const T &inValue)
   {
      cpp::Variant &v = _hx_getFixed()[inIndex];
      v = inValue;
      #ifdef HXCPP_GC_GENERATIONAL
      if (v.type <= cpp::Variant::typeString)
         HX_OBJ_WB_GET(this, v.valObject);
      #endif
      return this;
   }

   inline ::Dynamic     __Param(int inID)              { return _hx_getFixed()[inID]; }
   inline ::Dynamic     _hx_getObject(int inId)        { return _hx_getFixed()[inId].asDynamic(); }
   inline ::Dynamic     _hx_getParamI(int inId)        { return _hx_getFixed()[inId]; }
   inline int           _hx_getInt(int inId)           { return _hx_getFixed()[inId]; }
   inline ::cpp::Int64  _hx_getInt64(int inId)         { return _hx_getFixed()[inId].asInt64(); }
   inline Float         _hx_getFloat(int inId)         { return _hx_getFixed()[inId]; }
   inline bool          _hx_getBool(int inId)          { return _hx_getFixed()[inId]; }
   inline ::String      _hx_getString(int inId)        { return _hx_getFixed()[inId].asString(); }
   inline int           _hx_getParamCount()  const noexcept { return mFixedFields; }

   DynamicArray _hx_getParameters();
   Dynamic      __GetItem(int inIndex) const;

   inline String _hx_getTag()   const noexcept { return _hx_tag; }
   inline int    _hx_getIndex() const noexcept { return index;   }
   inline String __Tag()        const noexcept { return _hx_tag; }

   int __Compare(const hx::Object *inRHS) const override;
};

typedef hx::ObjectPtr<EnumBase_obj> EnumBase;

HXCPP_EXTERN_CLASS_ATTRIBUTES bool __hxcpp_enum_eq(::hx::EnumBase a, ::hx::EnumBase b);

template<typename ENUM>
inline ENUM *CreateEnum(const String &inName, int inIndex, int inFields)
{
   ENUM *result = new(inFields * sizeof(cpp::Variant)) ENUM;
   result->_hx_setIdentity(inName, inIndex, inFields);
   return result;
}

template<typename ENUM>
inline ENUM *CreateConstEnum(const String &inName, int inIndex)
{
   ENUM vtable;
   ENUM *result = static_cast<ENUM *>(hx::InternalCreateConstBuffer(&vtable, sizeof(ENUM)));
   result->_hx_setIdentity(inName, inIndex, 0);
   return result;
}

}

inline int _hx_getEnumValueIndex(hx::EnumBase inEnum) noexcept
{
   return inEnum->_hx_getIndex();
}

inline void __hxcpp_enum_force(hx::EnumBase inEnum, String inForceName, int inIndex) noexcept
{
   inEnum->_hx_setIdentity(inForceName, inIndex, 0);
}

#endif
