#
# Component Makefile
#

COMPONENT_ADD_INCLUDEDIRS := include $(IDF_TARGET)/include
COMPONENT_SRCDIRS := src

ifndef CONFIG_ESP32_NO_BLOBS
    LIBS := core rtc net80211 pp wpa smartconfig coexist wps wpa2 espnow phy mesh
    COMPONENT_ADD_LDFLAGS += -L$(COMPONENT_PATH)/lib_$(IDF_TARGET) \
                          $(addprefix -l,$(LIBS))

    COMPONENT_ADD_LDFRAGMENTS += linker.lf

    COMPONENT_SUBMODULES += lib_$(IDF_TARGET)

    ALL_LIB_FILES := $(patsubst %,$(COMPONENT_PATH)/lib_$(IDF_TARGET)/lib%.a,$(LIBS))
    COMPONENT_ADD_LINKER_DEPS += $(ALL_LIB_FILES)
endif

