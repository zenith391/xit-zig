const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Task = struct {
    state: State,
    description: [:0]const u8,

    pub const State = enum {
        open,
        checked,
        ongoing,
        obsolete,

        pub fn toString(self: State) [:0]const u8 {
            return switch (self) {
                .open => " ",
                .checked => "x",
                .ongoing => "@",
                .obsolete => "~",
            };
        }
    };
};

pub const TaskGroup = struct {
    name: ?[:0]const u8,
    tasks: []const Task,
};

pub const XitFile = struct {
    allocator: Allocator,
    groups: []const TaskGroup,

    pub fn load(allocator: Allocator, reader: anytype) !XitFile {
        var taskGroups = std.ArrayList(TaskGroup).init(allocator);

        var currentGroupName: ?[:0]const u8 = null;
        var currentGroupTasks = std.ArrayList(Task).init(allocator);
        while (true) {
            const unescaped_line = (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize))) orelse break;
            defer allocator.free(unescaped_line);

            const line = blk: {
                if (std.mem.lastIndexOfScalar(u8, unescaped_line, '\r')) |pos| {
                    // If \r is found, exclude it from the line.
                    // This way the whole line delimiter has been removed (\r\n)
                    break :blk unescaped_line[0..pos];
                } else {
                    // If \r isn't found, as the line already got its
                    // line delimiter (\n) removed, we just return it.
                    break :blk unescaped_line;
                }
            };

            // Task item
            if (line.len >= 3 and line[0] == '[' and line[2] == ']') {
                const state: Task.State = switch (line[1]) {
                    ' ' => .open,
                    'x' => .checked,
                    '@' => .ongoing,
                    '~' => .obsolete,
                    else => return error.InvalidTaskState,
                };

                // Skip all spaces
                var descriptionStart: usize = 3;
                while (line[descriptionStart] == ' ') {
                    descriptionStart += 1;
                }

                try currentGroupTasks.append(Task{
                    .state = state,
                    .description = try allocator.dupeZ(u8, line[descriptionStart..]),
                });
            } else if (line.len == 0 and currentGroupTasks.items.len > 0) {
                // If it's a blank line and the group isn't empty,
                // push the current group and create a new one
                try taskGroups.append(TaskGroup{
                    .name = currentGroupName,
                    .tasks = currentGroupTasks.toOwnedSlice(),
                });
                currentGroupName = null;
                // toOwnedSlice already cleared currentGroupTasks
            } else {
                currentGroupName = try allocator.dupeZ(u8, line);
            }
        }

        if (currentGroupTasks.items.len > 0) {
            // Push the last group if it hasn't been yet
            try taskGroups.append(TaskGroup{
                .name = currentGroupName,
                .tasks = currentGroupTasks.toOwnedSlice(),
            });
        }

        return XitFile{ .allocator = allocator, .groups = taskGroups.toOwnedSlice() };
    }

    pub fn loadFromFile(allocator: Allocator, file: std.fs.File) !XitFile {
        var buffer = std.io.bufferedReader(file.reader());
        return XitFile.load(allocator, buffer.reader());
    }

    pub fn deinit(self: XitFile) void {
        for (self.groups) |group| {
            for (group.tasks) |task| {
                self.allocator.free(task.description);
            }
            if (group.name) |name| self.allocator.free(name);
            self.allocator.free(group.tasks);
        }
    }
};
