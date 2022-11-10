    #
    # hrfilesize--
    #   Convert a size in byte into a human readable form.
    #   http://en.wikipedia.org/wiki/Byte
    #   http://en.wikipedia.org/wiki/File_size
    #   http://physics.nist.gov/cuu/Units/binary.html
    #
    #   Copyright: Michael Baudin, 2008, michael.baudin@gmail.com
    #

    package provide hrfilesize 1.0

    namespace eval hrfilesize  {
        # System used to convert from bytes into the new unit
        variable unitsystem
        # Format used to convert from real file size to string
        variable realformat
        # Integer to convert from 1 byte (binary or decimal) into the new unit
        variable kilobytes
        # This is a map from the power to the unit name
        variable powertounitmap
        # Maximum available power
        variable powermax 6
        # Component used to process the integers
        variable integerpackage
    }

    #
    # hrfilesize::bytestohr --
    #   Returns a string containing an human-readable form
    #   representing the given size in bytes by computing
    #   the size in the suitable units :
    #   - bytes,
    #   - kilobytes,
    #   - megabytes,
    #   - gigabytes,
    #   - terabytes,
    #   - petabytes,
    #   - exabytes.
    # Example:
    #   If one have a 10 000 bytes file :
    #     hrfilesize::bytestohr 10000
    #   returns "10.0 KB"
    # Arguments:
    #   size: the size in bytes
    #   -realformat value : the format used to convert from the full real size
    #      to a sexy short real. Defaults to "%.1f"
    #   -unit value : the unit system to convert from bytes.
    #      If "value" is "binary" then one kilobyte is made of 1024 bytes.
    #      If "value" is "decimal" then one kilobyte is made of 1000 bytes.
    #      The default unit system is decimal.
    #   -integerpackage value : the package to process integer values
    #      If "value" is "Tcl" then the integers are processed with Tcl "expr" command
    #      If "value" is "bigfloat" then the integers are processed with Tcl lib package "bigfloat"
    #
    proc hrfilesize::bytestohr {size args} {
        #
        # Process options
        #
        foreach {key value} $args {
            hrfilesize::configure $key $value
        }
        #
        # Compute the size in the new unit
        #
        set newsize [hrfilesize::newsize $size]
        set y [lindex $newsize 0]
        set power [lindex $newsize 1]
        # Limits the power to 6
        if {$power>$hrfilesize::powermax} then {
            error "File size larger than the maximum available size unit (power : $power)"
        }
        array set unitarray $hrfilesize::powertounitmap
        set unit $unitarray($power)
        set shortdouble [format $hrfilesize::realformat $y]
        set result "$shortdouble $unit"
        return $result
    }
    #
    # hrfilesize::configure --
    #   Configure the conversion system depending on the couples (key,value)
    #   given in the list args.
    # Arguments:
    #   -realformat value : the format used to convert from the full real size
    #      to a sexy short real. Defaults to "%.1f"
    #   -unit value : the unit system to convert from bytes.
    #      If "value" is "binary" then one kilobyte is made of 1024 bytes.
    #      If "value" is "decimal" then one kilobyte is made of 1000 bytes.
    #   -integerpackage value : the package to process integer values
    #      If "value" is "Tcl" then the integers are processed with Tcl "expr" command
    #      If "value" is "bigfloat" then the integers are processed with Tcl lib package "bigfloat"
    #
    proc hrfilesize::configure {args} {
        #
        # Process options
        #
        foreach {key value} $args {
            switch -- $key {
                "-realformat" {
                    set hrfilesize::realformat $value
                }
                "-unit" {
                    set hrfilesize::unitsystem $value
                }
                "-integerpackage" {
                    set hrfilesize::integerpackage $value
                }
                default {
                    error "Unknown key $key"
                }
            }
        }
        #
        # Configure internal settings depending on the unit system
        #
        switch -- $hrfilesize::unitsystem {
            "binary" {
                set hrfilesize::kilobytes 1024
                set hrfilesize::powertounitmap [list 0 "B" \
                                                    1 "KiB" \
                                                    2 "MiB" \
                                                    3 "GiB" \
                                                    4 "TiB" \
                                                    5 "PiB" \
                                                    6 "EiB" \
                                                    ]
            }
            "decimal" {
                set hrfilesize::kilobytes 1000
                set hrfilesize::powertounitmap [list 0 "B" \
                                                    1 "KB" \
                                                    2 "MB" \
                                                    3 "GB" \
                                                    4 "TB" \
                                                    5 "PB" \
                                                    6 "EB" \
                                                    ]
            }
            default {
                error "Unknown unit $unit"
            }
        }
        return ""
    }
    #
    # hrfilesize::newsize --
    #   Returns a couple made of two items :
    #   - the size in the new unit (y),
    #   - the power of the kilobytes multiple,
    #   that is, computes newsize and power such that :
    #     size = y x 1000^power if the unit is decimal
    #     size = y x 1024^power if the unit is binary
    #
    proc hrfilesize::newsize {size} {
        switch -- $hrfilesize::integerpackage {
            "Tcl" {
                set result [hrfilesize::newsize_tcl $size]
            }
            "bigfloat" {
                set result [hrfilesize::newsize_bifloat $size]
            }
            default {
                error "Unknown integer package $hrfilesize::integerpackage"
            }
        }
        return $result
    }
    #
    # hrfilesize::newsize_tcl --
    #   Compute the new size based on Tcl "expr" command.
    #
    # Limitations
    #   Tcl string to integer conversion is based on the C integer long type,
    #   so that the maximum integer is approximately 2 GB if we suppose that
    #   the long integer is based on 32 bits.
    #   If the given size is greater that 2 GB, the Tcl "expr" command
    #   will fail to process the integer.
    #
    proc hrfilesize::newsize_tcl {size} {
        set y [expr {double($size)}]
        set power 0
        while {$y >= $hrfilesize::kilobytes } {
            incr power
            set y [expr {$y / double($hrfilesize::kilobytes)}]
        }
        return [list $y $power]
    }
    #
    # hrfilesize::newsize_bifloat --
    #   Compute the new size based on the bigfloat package.
    #
    proc hrfilesize::newsize_bifloat {size} {
        package require math::bigfloat
        set y [math::bigfloat::fromstr $size]
        set y [math::bigfloat::int2float $y]
        set kb [math::bigfloat::fromstr $hrfilesize::kilobytes]
        set kb [math::bigfloat::int2float $kb]
        set power 0
        set compare [math::bigfloat::compare $y $kb]
        while {$compare>=0 } {
            incr power
            set y [math::bigfloat::div $y $kb]
            set compare [math::bigfloat::compare $y $kb]
        }
        set y [math::bigfloat::todouble $y]
        return [list $y $power]
    }
    #
    # compare --
    #   Compare two files sizes represented in human readable form, and
    #   return -1 if size1 in less than size2, 0 if size1 and
    #   size2 are equal or 1 if size2 is greater than size2.
    #   The two file sizes may be in different units but in the same
    #   unit system, that is, the two values in decimal units, or the two
    #   values in binary units.
    # Arguments:
    #   size1, size2: the size of the first file/directory which is a list of two items
    #     as returned by "bytestohr" :
    #     - the first item is a real value representing the size,
    #     - the second item is the unit.
    #   -unit value : the unit system to convert from bytes.
    #      If "value" is "binary" then one kilobyte is made of 1024 bytes.
    #      If "value" is "decimal" then one kilobyte is made of 1000 bytes.
    #      The default unit system is decimal.
    #   -integerpackage value : the package to process integer values
    #      If "value" is "Tcl" then the integers are processed with Tcl "expr" command
    #      If "value" is "bigfloat" then the integers are processed with Tcl lib package "bigfloat"
    #
    proc hrfilesize::compare {size1 size2 args} {
        #
        # Process options
        #
        foreach {key value} $args {
            hrfilesize::configure $key $value
        }
        #
        # Get values and units
        #
        set size1value [lindex $size1 0]
        set size1unit [lindex $size1 1]
        set size2value [lindex $size2 0]
        set size2unit [lindex $size2 1]
        #
        # The two values are in the same unit :
        # compare the values.
        #
        if {$size1unit==$size2unit} then {
            if {$size1value < $size2value} then {
                set compare -1
            } elseif {$size1value == $size2value} then {
                set compare 0
            } else {
                set compare 1
            }
        } else {
            #
            # Compare the units
            #
            set unit1index [lsearch $hrfilesize::powertounitmap $size1unit]
            set unit2index [lsearch $hrfilesize::powertounitmap $size2unit]
            if {$unit1index==-1 || $unit2index==-1} then {
                error "The current unit system $hrfilesize::unitsystem does not match the given units for $size1 and $size2."
            }
            if {$unit1index < $unit2index} then {
                set compare -1
            } else {
                set compare 1
            }
        }
        return $compare
    }
    #
    # Automatic configuration of the package at loading.
    #
    hrfilesize::configure -unit "decimal"
    hrfilesize::configure -realformat "%.1f"
    hrfilesize::configure -integerpackage "bigfloat"
