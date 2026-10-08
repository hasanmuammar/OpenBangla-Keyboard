add_subdirectory(common)

corrosion_import_crate(
    MANIFEST_PATH riti/Cargo.toml
    CRATE_TYPES staticlib
    CRATES riti
)

if(ENABLE_IBUS)
    add_subdirectory(ibus)
endif()

if(ENABLE_FCITX)
    add_subdirectory(fcitx)
endif()
