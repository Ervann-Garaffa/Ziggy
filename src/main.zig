const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const FRAME_WIDTH = 900;
const FRAME_HEIGHT = FRAME_WIDTH;
const FRAME_OFFSET = 20;
const MENU_WIDTH = 200;
const WINDOW_WIDTH = FRAME_WIDTH + 2 * FRAME_OFFSET + MENU_WIDTH;
const WINDOW_HEIGHT = FRAME_HEIGHT + 2 * FRAME_OFFSET;

const Button = struct {
    body: rl.Rectangle,
    name: []const u8,
};

pub fn nullTermString(input: []const u8) [32]u8 {
    var text_buffer: [32]u8 = undefined;
    const text_len = @min(text_buffer.len - 1, input.len);
    std.mem.copyBackwards(u8, text_buffer[0..text_len], input[0..text_len]);
    text_buffer[text_len] = 0;
    return text_buffer;
}

const ship_shape: [6]rl.Vector2 = .{
    .{ .x = -5, .y = -4 },
    .{ .x = 5, .y = 0 },
    .{ .x = -5, .y = 4 },
    .{ .x = -4, .y = 2 },
    .{ .x = -4, .y = -2 },
    .{ .x = -5, .y = -4 },
};

const Ship = struct {
    position: rl.Vector2,
    speed: rl.Vector2,
    rotation: f32,
    scale: f32,
    body: [6]rl.Vector2,

    fn init(self: *@This()) void {
        //self.body = ship_shape;
        self.scale = 2;
        self.rotation = 0;
        self.speed = .{ .x = 0.0, .y = 0 };
        self.position = .{ .x = 400, .y = 200 };
    }

    fn update(self: *@This()) void {
        self.position = rl.Vector2Add(self.position, self.speed);

        // Boundaries checking
        if (self.position.x < FRAME_OFFSET + 5 * self.scale) { self.position.x = FRAME_OFFSET + 5 * self.scale; } 
        else if (self.position.x > FRAME_OFFSET + FRAME_WIDTH - 5 * self.scale) { self.position.x = FRAME_OFFSET + FRAME_WIDTH - 5 * self.scale; }
        if (self.position.y < FRAME_OFFSET + 5 * self.scale) { self.position.y = FRAME_OFFSET + 5 * self.scale; } 
        else if (self.position.y > FRAME_OFFSET + FRAME_HEIGHT - 5 * self.scale) { self.position.y = FRAME_OFFSET + FRAME_HEIGHT - 5 * self.scale; }        

        self.body = ship_shape;
        transformRLV2Slice(self.body[0..], self.scale, self.rotation, self.position);
    }
};

// YES! Array modification through slices without using a f*cking Allocator! Thanks again Claude
pub fn transformRLV2Slice(
    points: []rl.Vector2, // Slice called same as an array but with unknown length : slice[0..]
    scale: f32,
    rotation: f32,
    translation: rl.Vector2,
) void {
    for (points) |*point| { // Capture the pointer of each element (incremented in memory with size of the object)
        const scaled_point = rl.Vector2Scale(point.*, scale); // Dereferenced pointer to access the actual object
        const rotated_point = rl.Vector2Rotate(scaled_point, rotation);
        point.* = rl.Vector2Add(rotated_point, translation); // idem : dereferenced pointer to modify the actual object
    }
}

pub fn main() !void {
    rl.SetTraceLogLevel(rl.LOG_NONE);
    rl.InitWindow(WINDOW_WIDTH,WINDOW_HEIGHT, "Hello");
    defer rl.CloseWindow();
    rl.SetTargetFPS(120);

    var ship: Ship = undefined;
    ship.init();

    while (!rl.WindowShouldClose()) { // Set ! back to work
        rl.BeginDrawing();
        defer rl.EndDrawing();

        ship.speed = rl.Vector2Zero();
        if (rl.IsKeyDown(rl.KEY_UP)) {
            ship.speed = rl.Vector2Add(ship.speed, .{ .x = 0, .y = -1 });
        }
        if (rl.IsKeyDown(rl.KEY_DOWN)) {
            ship.speed = rl.Vector2Add(ship.speed, .{ .x = 0, .y = 1 });
        }
        if (rl.IsKeyDown(rl.KEY_RIGHT)) {
            ship.speed = rl.Vector2Add(ship.speed, .{ .x = 1, .y = 0 });
        }
        if (rl.IsKeyDown(rl.KEY_LEFT)) {
            ship.speed = rl.Vector2Add(ship.speed, .{ .x = -1, .y = 0 });
        }

        if (0 == rl.Vector2Equals(ship.speed, rl.Vector2Zero())) {
            ship.speed = rl.Vector2Normalize(ship.speed);
            ship.rotation = rl.Vector2Angle(rl.Vector2{ .x = 1, .y = 0 }, ship.speed);
        }

        ship.update();
        rl.ClearBackground(rl.BLACK);
        rl.DrawRectangleLines(FRAME_OFFSET, FRAME_OFFSET, FRAME_WIDTH, FRAME_HEIGHT, rl.WHITE);
        rl.DrawText("Score : ", WINDOW_WIDTH - MENU_WIDTH + 20, 20, 30, rl.WHITE);
        
        rl.DrawLineStrip(&ship.body, ship.body.len, rl.WHITE);
    }
}
