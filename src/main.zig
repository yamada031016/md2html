const std = @import("std");
const convert = @import("convert.zig").convert;

pub fn main() !void {
    var args = std.process.args();
    const exe_name = args.next().?;
    const css_path = args.next() orelse {
        std.log.err("Usage: {s} <css dir>", .{exe_name});
        return;
    };

    const dir = try std.fs.cwd().openDir(css_path, .{.iterate=true});
    var walker = try dir.walk(std.heap.page_allocator);
    const output_dir = try std.fs.cwd().openDir("html", .{.iterate=true});
    var terminator = try output_dir.walk(std.heap.page_allocator);
    while (try terminator.next()) |entry| {
        switch(entry.kind) {
            .directory => {
                output_dir.deleteTree(entry.path) catch |e| {
                    std.debug.print("{s}: at {s}\n", .{@errorName(e), entry.path});
                };
            },
            .file => {
                output_dir.deleteFile(entry.path) catch |e| {
                    std.debug.print("{s}: at {s}\n", .{@errorName(e), entry.path});
                };
            },
            else => {},
        }
    }

    while (try walker.next()) |file| {
        switch(file.kind) {
            .file => {
                var buf:[4096]u8 = undefined;
                const css = try file.dir.openFile(file.path, .{});
                const css_len = try css.readAll(&buf);
                const html = try convert(buf[0..css_len]);
                const output = try output_dir.createFile(try std.fmt.allocPrint(std.heap.page_allocator, "{s}.html", .{std.fs.path.stem(file.path)}), .{});
                try output.writeAll(html);
                std.debug.print("{s}\n", .{html});
            },
            else => {},
        }
    }
}
