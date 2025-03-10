const std = @import("std");
pub fn coloredLog(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    switch (level) {
        .err => {
            const writer = std.io.getStdErr().writer();
            _ = writer.write("\x1B[0;31m") catch unreachable;
            writer.print(format, args) catch unreachable;
            _ = writer.write("\x1B[0m") catch unreachable;
        },

        else => {
            const writer = std.io.getStdErr().writer();
            std.fmt.format(writer, format, args) catch unreachable;
        },
    }
    _ = scope;
}
