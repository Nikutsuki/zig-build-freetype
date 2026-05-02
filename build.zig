const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libpng_enabled = b.option(bool, "enable-libpng", "Build libpng") orelse false;

    const lib = b.addLibrary(.{
        .name = "freetype",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const root = lib.root_module;

    if (target.result.os.tag == .linux) {
        root.linkSystemLibrary("m", .{});
    }

    const zlib_dep = b.dependency("zlib", .{ .target = target, .optimize = optimize });
    root.linkLibrary(zlib_dep.artifact("z"));

    if (libpng_enabled) {
        const libpng_dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });
        root.linkLibrary(libpng_dep.artifact("png"));
    }

    root.addIncludePath(b.path("upstream/include"));

    root.addConfigHeader(b.addConfigHeader(.{
        .style = .blank,
        .include_path = "freetype-zig.h",
    }, .{}));

    root.addIncludePath(b.path("include"));
    root.addIncludePath(b.path("upstream/include"));

    var flags = std.ArrayListUnmanaged([]const u8).empty;
    try flags.appendSlice(b.allocator, &.{
        "-DFT2_BUILD_LIBRARY",
        "-DFT_CONFIG_OPTION_SYSTEM_ZLIB=1",
        "-DHAVE_UNISTD_H",
        "-DHAVE_FCNTL_H",
        "-fno-sanitize=undefined",
    });
    defer flags.deinit(b.allocator);
    if (target.result.os.tag != .windows) {
        // Hide symbols so a process that also dlopens a system libfreetype
        // (e.g. via GTK/Pango/Cairo) does not mix our static archive with
        // the system shared library at runtime.
        try flags.appendSlice(b.allocator, &.{
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        });
    }
    if (libpng_enabled) try flags.append(b.allocator, "-DFT_CONFIG_OPTION_USE_PNG=1");

    root.addCSourceFiles(.{
        .root = b.path(""),
        .files = srcs,
        .flags = flags.items,
    });

    const os_tag = target.result.os.tag;

    const ftsystem_path = switch (os_tag) {
        .linux => "upstream/builds/unix/ftsystem.c",
        .windows => "upstream/builds/windows/ftsystem.c",
        else => "upstream/src/base/ftsystem.c",
    };
    root.addCSourceFile(.{ .file = b.path(ftsystem_path), .flags = flags.items });

    if (os_tag == .windows) {
        root.addCSourceFile(.{ .file = b.path("upstream/builds/windows/ftdebug.c"), .flags = flags.items });
        lib.root_module.addWin32ResourceFile(.{
            .file = b.path("upstream/src/base/ftver.rc"),
        });
    } else {
        root.addCSourceFile(.{ .file = b.path("upstream/src/base/ftdebug.c"), .flags = flags.items });
    }

    lib.installHeader(b.path("include/freetype-zig.h"), "freetype-zig.h");
    lib.installHeader(b.path("upstream/include/ft2build.h"), "ft2build.h");
    lib.installHeadersDirectory(b.path("upstream/include/freetype"), "freetype", .{});

    b.installArtifact(lib);
}

const srcs = &.{
    "upstream/src/autofit/autofit.c",
    "upstream/src/base/ftbase.c",
    "upstream/src/base/ftbbox.c",
    "upstream/src/base/ftbdf.c",
    "upstream/src/base/ftbitmap.c",
    "upstream/src/base/ftcid.c",
    "upstream/src/base/ftfstype.c",
    "upstream/src/base/ftgasp.c",
    "upstream/src/base/ftglyph.c",
    "upstream/src/base/ftgxval.c",
    "upstream/src/base/ftinit.c",
    "upstream/src/base/ftmm.c",
    "upstream/src/base/ftotval.c",
    "upstream/src/base/ftpatent.c",
    "upstream/src/base/ftpfr.c",
    "upstream/src/base/ftstroke.c",
    "upstream/src/base/ftsynth.c",
    "upstream/src/base/fttype1.c",
    "upstream/src/base/ftwinfnt.c",
    "upstream/src/bdf/bdf.c",
    "upstream/src/bzip2/ftbzip2.c",
    "upstream/src/cache/ftcache.c",
    "upstream/src/cff/cff.c",
    "upstream/src/cid/type1cid.c",
    "upstream/src/gzip/ftgzip.c",
    "upstream/src/lzw/ftlzw.c",
    "upstream/src/pcf/pcf.c",
    "upstream/src/pfr/pfr.c",
    "upstream/src/psaux/psaux.c",
    "upstream/src/pshinter/pshinter.c",
    "upstream/src/psnames/psnames.c",
    "upstream/src/raster/raster.c",
    "upstream/src/sdf/sdf.c",
    "upstream/src/sfnt/sfnt.c",
    "upstream/src/smooth/smooth.c",
    "upstream/src/svg/svg.c",
    "upstream/src/truetype/truetype.c",
    "upstream/src/type1/type1.c",
    "upstream/src/type42/type42.c",
    "upstream/src/winfonts/winfnt.c",
    "upstream/src/hvf/hvf.c",
};
