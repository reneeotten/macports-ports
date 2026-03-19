# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# Usage:
# PortGroup     eigen 1.0
#
# This port group handles setting ports up to build against specific eigen versions

namespace eval eigen { }

options eigen.version
default eigen.version 3

options eigen.depends_type
default eigen.depends_type build

# cache variables storing current configuration state
default eigen_cache_version       ""
default eigen_cache_depends       ""
default eigen_cache_cpath         ""
default eigen_cache_cppflags      ""
default eigen_cache_cxxflags      ""
default eigen_cache_ldflags       ""
default eigen_cache_cmake_flags   ""
default eigen_cache_pkgconfig_flags   ""
default eigen_cache_env_vars      ""

proc eigen::version {} {
    return [option eigen.version]
}

proc eigen::install_area {} {
    global prefix
    return ${prefix}/libexec/eigen[eigen::version]
}

proc eigen::include_dir {} {
    return [eigen::install_area]/include/eigen3
}

proc eigen::lib_dir {} {
    return [eigen::install_area]/lib
}

proc eigen::depends_portname {} {
    return eigen[eigen::version]
}

proc eigen::cxx_flags {} {
    return -I[eigen::include_dir]
}

proc eigen::ld_flags {} {
    return -L[eigen::lib_dir]
}

proc eigen::cpp_flags {} {
    return -I[eigen::include_dir]
}

proc eigen::configure_build {} {
    global cmake.build_dir
    global eigen_cache_version eigen_cache_depends eigen_cache_cxxflags
    global eigen_cache_ldflags eigen_cache_cmake_flags eigen_cache_pkgconfig_flags
    global eigen_cache_env_vars eigen_cache_cpath eigen_cache_cppflags

    ui_debug "eigen PG: Configure build for eigen[eigen::version]"

    # Set the requested eigen dependency
    if { ${eigen_cache_version} ne "" && ${eigen_cache_depends} ne "" } {
        depends_${eigen_cache_depends}-delete port:eigen${eigen_cache_version}
    }
    set eigen_cache_depends       [option eigen.depends_type]
    set eigen_cache_version       [eigen::version]
    depends_[option eigen.depends_type]-append port:eigen[eigen::version]

    # Append to the build flags to find the isolated headers/libs
    if { ${eigen_cache_cppflags} ne "" } {
        configure.cppflags-delete ${eigen_cache_cppflags}
    }
    if { ${eigen_cache_cxxflags} ne "" } {
        configure.cxxflags-delete ${eigen_cache_cxxflags}
    }
    if { ${eigen_cache_ldflags} ne "" } {
        configure.ldflags-delete ${eigen_cache_ldflags}
    }
    set eigen_cache_cppflags [eigen::cpp_flags]
    set eigen_cache_cxxflags [eigen::cxx_flags]
    set eigen_cache_ldflags  [eigen::ld_flags]
    configure.cppflags-prepend ${eigen_cache_cppflags}
    configure.cxxflags-prepend ${eigen_cache_cxxflags}
    configure.ldflags-prepend  ${eigen_cache_ldflags}

    # Some build systems (meson,makefile) need configure/build env vars to be set.
    # Do this unconditionally, as setting env vars shouldn't harm builds
    # that do not use them.
    if { ${eigen_cache_env_vars} ne "" } {
        foreach var ${eigen_cache_env_vars} {
            foreach phase {configure build} {
                ${phase}.env-delete ${var}
            }
        }
    }

    # if pkg-config is used, make sure the correct eigen3.pc is found
    if { ${eigen_cache_pkgconfig_flags} ne "" } {
        configure.pkg_config_path-delete [eigen::install_area]/share/pkgconfig
    }
    set eigen_cache_pkgconfig_flags     [eigen::install_area]/share/pkgconfig
    configure.pkg_config_path-prepend   ${eigen_cache_pkgconfig_flags}

    ### FIXME
    set eigen_cache_env_vars [list \
                                Eigen3_DIR=[eigen::install_area]/share/eigen3/cmake \
                                EIGEN3_INCLUDE_DIR=[eigen::include_dir] \
                                EIGEN_ROOT=[eigen::install_area] \
                                EIGEN_ROOT_DIR=[eigen::install_area]
                             ]
    foreach var ${eigen_cache_env_vars} {
        foreach phase {configure build destroot} {
            ${phase}.env-append ${var}
        }
    }

    # Add to compiler.cpath. Helps with e.g. meson builds. See discussion at
    if { ${eigen_cache_cpath} ne "" } {
        compiler.cpath-delete ${eigen_cache_cpath}
    }
    set eigen_cache_cpath [eigen::include_dir]
    compiler.cpath-prepend ${eigen_cache_cpath}

    # Are we using cmake ?
    # As we are appending to configure flags, need to check if cmake is in use
    # before appending the cmake specific flags
    if { [string match *cmake* [option configure.cmd] ] } {
        if { ${eigen_cache_cmake_flags} ne "" } {
            foreach flag ${eigen_cache_cmake_flags} {
                configure.args-delete ${flag}
            }
            cmake.module_path-prepend   [eigen::install_area]/share/eigen3/cmake
        }

        set eigen_cache_cmake_flags [list \
                                        -DEigen3_DIR=[eigen::install_area]/share/eigen3/cmake \
                                        -DEIGEN3_INCLUDE_DIR=[eigen::include_dir] \
                                        -DEIGEN_ROOT=[eigen::install_area] \
                                        -DEIGEN_ROOT_DIR=[eigen::install_area]
                                    ]
        foreach flag ${eigen_cache_cmake_flags} {
            configure.args-append ${flag}
        }
    }
}

port::register_callback eigen::configure_build

eigen::configure_build

proc eigen::set_eigen_parameters {option action args} {
    if {$action ne  "set"} return
    eigen::configure_build
}
option_proc eigen.version       eigen::set_eigen_parameters
option_proc eigen.depends_type  eigen::set_eigen_parameters
