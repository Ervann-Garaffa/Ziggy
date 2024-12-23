const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

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
        self.scale = 5;
        self.rotation = 0;
        self.speed = .{ .x = 0.0, .y = 0 };
        self.position = .{ .x = 400, .y = 200 };
    }

    fn update(self: *@This()) void {
        self.position = rl.Vector2Add(self.position, self.speed);
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
    rl.InitWindow(1200, 800, "Hello");
    rl.SetTargetFPS(144);

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
        rl.DrawLineStrip(&ship.body, ship.body.len, rl.WHITE);
    }
}
