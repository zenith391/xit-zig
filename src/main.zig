const std = @import("std");
const zgt = @import("zgt");
const XitFile = @import("xit.zig").XitFile;
pub usingnamespace zgt.cross_platform;

fn TodoTask(task: [:0]const u8) anyerror!zgt.Container_Impl {
    return zgt.Row(.{}, .{ zgt.Button(.{ .label = "[ ]" }), zgt.Label(.{ .text = task }) });
}

pub fn main() !void {
    try zgt.backend.init();
    var window = try zgt.Window.init();
    window.resize(1000, 600);
    try window.set(zgt.Column(.{}, .{
        zgt.Label(.{ .text = "TODO list -- with [x]it!" }),
        zgt.Column(.{ .name = "task-list" }, .{}),
    }));
    window.show();

    const file = try std.fs.cwd().openFile("test.xit", .{ .mode = .read_only });
    defer file.close();
    const xit = try XitFile.loadFromFile(zgt.internal.lasting_allocator, file);
    defer xit.deinit();
    std.log.info("file: {}", .{xit});

    const taskList = window.getChild().?.as(zgt.Container_Impl).getAs(zgt.Container_Impl, "task-list").?;
    for (xit.groups) |group| {
        const name = group.name orelse "";
        try taskList.add(zgt.Label(.{ .text = name }));

        std.debug.print("{s}\n", .{name});
        for (group.tasks) |task| {
            std.debug.print("  {s} {s}\n", .{ @tagName(task.state), task.description });

            try taskList.add(try zgt.Row(.{}, .{
                zgt.Button(.{ .label = task.state.toString() }),
                zgt.Label(.{ .text = task.description }),
            }));
        }
    }

    zgt.runEventLoop();
}
