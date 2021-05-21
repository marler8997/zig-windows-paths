```
+        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
+        // NOTE!
+        // We need to hande the case where the path starts with a "disk designator" but no
+        // lead slash (i.e. "C:" or "D:").  This path would be relative to the current
+        // directory of the drive, which would only match the current directory if it's
+        // also on the same drive!
+        // Maybe for now we can detect this and assert an error?
+        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
+        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//enum StrKind = enum { a, w };
//fn Char(comptime kind: StrKind) type { return if (kind == .a) u8 else u16; }

// Note: If a path starts with \?\, then it has already been normalized, zig should
//       not try to validate/normalize it.
//       see https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
// Note: Should zig support u8 paths that start with \?\, does windows do this at all?
// 
//

// Win32 Namespaces:
// https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
// --------------------------------------------------------------------------------
//   \\?\    The Win32 File Namespace
//           disable all parsing and send it straight to the filesystem
//           can be used to exceed the win32 max path limit (ensure you're using unicode functions)
//           can be used to pass reserved characters like ".." and "." to the filesystem
//           not all API's support this, check docs
//   \\.\    The Win32 Device Namespace
//           access physical disks/volumes and many other kinds of devices
//           does not work with most APIs, only ones meant to work with devices (i.e. CreateFile)
//           examples: \\.\COM56  \\.\CdRom3 \\.\PhysicalDisk0
//
// File Path Formats
// https://docs.microsoft.com/en-us/dotnet/standard/io/file-path-formats
// --------------------------------------------------------------------------------
// 1. Traditional DOS path
//     - volume/drive letter followed by a volume separator ":"
//     - the path
//     - examples
//       C:\foo\bar.txt  (absolute file from root of drive "C:")
//       \foo\bar.txt    (absolute path from root fo current drive)
//       foo\bar.txt     (relative path to the current directory)
//       ..\foo\bar
//       C:foo\bar       (relative path to the current directory of dirve "C:")
// 2. UNC Path
//     - to backslashes "\\" followed by a server host name
//     - a backslash then a share name
//     - note the servier/share name make up the "volume"
//     - then the path
//     - UNC paths are always fully qualified
//     - example
//       \\system7\C$\
//       \\server2\share\test\foo.txt
// 3. DOS device paths
//     ...
//
// Path Normalization
// 1. identify the path (identify it how?)
// 2. applies the current directory if it's a relative path
// 3. canonicalize component/directory separators (what's a component?)
// 4. evaluate '.' and '..'
// 5. trim certain characters
// Can do this with https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfullpathnamea?
//
// 1. Identify Path
//     - NA: devicepath?  begin with "\\?" or "\\."
//     - NA: UNC path? beins with "\\" but is not a device path (not followed by "?" nor ".")
//     - NA: fully-qualified dos path, drive letter, volume sep ":", dir separator "\", i.e. "C:\foo"
//     - NA: legacy device (i.e. "CON", "LPT1")
//     - NeedCurrentDrive: relative to root of current drive, begin with "\" (i.e. "\foo")
//     - NeedDriveCurrentDirectory: relative to the current directory of a specified drive, drive letter, volume sep ":", i.e. "C:foo"
//     - NeedCurrentDirectory: relative to the current directory "foo\bar.txt" "..\bat.txt" ".\what"
//    The type of path determines:
//     1. does the current directory get applied?
//     2. what the "root" of the path is
//
//     NOTE: relative paths are a race condition in multlthreade apps that change the current directory/drive
//       
// 5 trim certani characters
//     - trailing period removed?
//     - if path does not end in separator ('\' maybe also '/'?), all trailing periods/spaces(ascii 0x20) are removed
// 
// Paths starting with `?` are NOT NORAMLIZED
// 
//
```