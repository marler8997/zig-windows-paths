const std = @import("std");

const al = std.heap.page_allocator;


pub const PWSTR = [*:0]u16;
pub const PSTR = [*:0]u8;

pub extern "KERNEL32" fn GetFullPathNameA(
    lpFileName: [*:0]const u8,
    nBufferLength: u32,
    lpBuffer: ?[*:0]u8,
    lpFilePart: ?*?PSTR,
) callconv(@import("std").os.windows.WINAPI) u32;

pub extern "KERNEL32" fn GetFullPathNameW(
    lpFileName: [*:0]const u16,
    nBufferLength: u32,
    lpBuffer: ?[*:0]u16,
    lpFilePart: ?*?PWSTR,
) callconv(@import("std").os.windows.WINAPI) u32;

// We'll need these to know whether or not to apply the current directory to a filename
const reserved_names = .{
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5",
    "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5",
    "LPT6", "LPT7", "LPT8", "LPT9",
};

const FullPathNameResult = struct {
    slice: [:0]u8,
    filename_ptr: ?[*:0]u8,
    pub fn filenameLen(self: FullPathNameResult) usize {
        std.debug.assert(self.filename_ptr != null);
        return self.slice.len - (@ptrToInt(self.filename_ptr) - @ptrToInt(self.slice.ptr));
    }
    pub fn getFilename(self: FullPathNameResult) [:0]u8 {
        std.debug.assert(self.filename_ptr != null);
        return self.filename_ptr.?[0 .. self.filenameLen() :0];
    }
};
fn getFullPathNameZ(allocator: *std.mem.Allocator, path: [:0]const u8) FullPathNameResult {
    //var buffer: [buffer_len]u8 = undefined;
    var filename_ptr: ?[*:0]u8 = undefined;
    const result = GetFullPathNameA(path, 0, null, &filename_ptr);
    if (result == 0) {
        std.debug.panic("GetFullPathNameA '{s}' failed with {}", .{path, std.os.windows.kernel32.GetLastError()});
    }
    const buffer = allocator.alloc(u8, result) catch @panic("out of memory");
    errdefer allocator.free(buffer);
    const result2 = GetFullPathNameA(path, result, std.meta.assumeSentinel(buffer, 0), &filename_ptr);
    std.debug.assert(result2 + 1 == result);
    if (filename_ptr != null) {
        std.debug.assert(@ptrToInt(filename_ptr) >= @ptrToInt(buffer.ptr));
        std.debug.assert(@ptrToInt(filename_ptr) <= @ptrToInt(buffer.ptr) + result2);
    }
    std.debug.assert(buffer[result2] == 0);
    return FullPathNameResult { .slice = buffer[0..result2 :0], .filename_ptr = filename_ptr };
}

fn logFullPathNameZ(comptime buffer_len: usize, comptime path: [:0]const u8) void {
    var buffer: [buffer_len]u8 = undefined;
    var filename_ptr: ?[*:0]u8 = undefined;
    const result = GetFullPathNameA(path, buffer.len, &buffer, &filename_ptr);
    std.debug.print("----------------------------------------------------------------------------\n", .{});
    std.debug.print("GetFullPathNameA(\"{s}\") = \"{}\"\n", .{path, result});
    if (result == 0) {
        std.debug.print("GetLastError: {}\n", .{std.os.windows.kernel32.GetLastError()});
    } else if (result <= buffer.len) {
        std.debug.print("Buffer({}): \"{s}\"\n", .{buffer.len, buffer[0..result]});
        std.debug.print("filename_ptr: \"{s}\"\n", .{filename_ptr});
    } else {
        std.debug.print("Buffer Too Small: need {}, have {}\n", .{result, buffer.len});
    }
}

const Options = struct {
    filename: ?[]const u8,
    apply_cwd: bool,
    normalize_sep: bool,
    resolve_dot_dirs: bool,
    trim: bool,
};

fn repl(comptime str: anytype, find_char: u8, replace_with: u8) [str.len :0]u8 {
    var result: [str.len :0] u8 = undefined;
    for (str) |c, i| {
        result[i] = if (c == find_char) replace_with else c;
    }
    return result;
}

fn testPath(comptime path: [:0]const u8, opt: Options) void {
    std.log.info("--------------------------------------------------------------", .{});
    std.log.info("path '{s}'", .{path});

    const full_path = getFullPathNameZ(al, path);
    defer al.free(full_path.slice);
    std.log.info("full '{s}'", .{full_path.slice});
    std.log.info("filename '{s}'", .{full_path.filename_ptr});
    if (opt.filename) |f| {
        std.debug.assert(full_path.filename_ptr != null);
        std.testing.expect(std.mem.eql(u8, f, full_path.getFilename()));
    } else {
        std.debug.assert(full_path.filename_ptr == null);
    }

    //logFullPathNameZ(100, path);

    if (opt.apply_cwd) {
        @panic("not impl");
    }


    {
        var path_slashes = comptime repl(path, '\\', '/');
        if (std.mem.startsWith(u8, &path_slashes, "//?")) {
            path_slashes[0] = '\\';
            path_slashes[1] = '\\';
            path_slashes[2] = '?';
        }
        std.log.info("with slashes '{s}'", .{&path_slashes});
        const norm_path = getFullPathNameZ(al, &path_slashes);
        defer al.free(norm_path.slice);
        std.log.info("    norm -> '{s}'", .{norm_path.slice});
        if (opt.normalize_sep) {
            std.testing.expect(std.mem.eql(u8, path, norm_path.slice));
        } else {
            std.testing.expect(std.mem.eql(u8, &path_slashes, norm_path.slice));
        }
    }

    {
        const path_dot_dirs = path ++ (if (path[path.len-1] == '\\') "" else "\\") ++ "foo\\..";
        std.log.info("with .. '{s}'", .{path_dot_dirs});
        const norm_path = getFullPathNameZ(al, path_dot_dirs);
        defer al.free(norm_path.slice);
        std.log.info("    norm -> '{s}'", .{norm_path.slice});
        if (opt.resolve_dot_dirs) {

        } else {
        }
    }
}

pub const log_level = std.log.Level.info;

pub fn main() !void {
    testPath("\\\\?\\foo\\bar", .{
        .filename = "bar",
        .apply_cwd = false,
        .normalize_sep = true,
        .resolve_dot_dirs = false,
        .trim = false,
    });
    testPath("C:\\", .{
        .filename = null,
        .apply_cwd = false,
        .normalize_sep = true,
        .resolve_dot_dirs = true,
        .trim = true,
    });
    testPath("C:\\LPT1", .{
        .filename = null,
        .apply_cwd = false,
        .normalize_sep = true,
        .resolve_dot_dirs = true,
        .trim = true,
    });
    //testPath("C::\\");

    //inline for (reserved_names) |rn| {
    //    try logFullPathNameZ(10, rn);
    //}
//
    //try logFullPathNameZ(3, "C:\\");
    //try logFullPathNameZ(5, "\\\\?\\");
    ////try logFullPathNameZ(10, "C:\\");
    ////try logFullPathNameZ(10, "C:\\..");
    ////std.debug.print("GetFullPathNameA"
}

//

// Operations
// apply current directory (may be for a different drive)
//
// normalize separators (single backslashes, one colon?)
// resolve dot dirs
// trim tailing dot/spaces
// 
//
// Begins with "\\?\"  parsing disabled, do not normalize at all
// Begins with "\\.\"  device path, do not normalize at all?
// Begins with "[a-zA-Z]:[/\]" absolute path, normalize
// Legacy device "COM" "LPT1" etc, ???
// Begins with "\" (not followed by second slash)



