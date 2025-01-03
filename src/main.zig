const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const globAlloc = std.heap.page_allocator;
const rand = std.crypto.random;

const FRAME_WIDTH = 900;
const FRAME_HEIGHT = FRAME_WIDTH;
const FRAME_OFFSET = 20;
const MENU_WIDTH = 200;
const WINDOW_WIDTH = FRAME_WIDTH + 2 * FRAME_OFFSET + MENU_WIDTH;
const WINDOW_HEIGHT = FRAME_HEIGHT + 2 * FRAME_OFFSET;
const TARGET_FPS = 120;

const Button = struct {
    body: rl.Rectangle,
    name: []const u8,
};

pub fn textToNullTermString(input: []const u8) [32]u8 { // Useful for converting []u8 into useable strings for rl.DrawText
    var text_buffer: [32]u8 = undefined;
    const text_len = @min(text_buffer.len - 1, input.len);
    std.mem.copyBackwards(u8, text_buffer[0..text_len], input[0..text_len]);
    text_buffer[text_len] = 0;
    return text_buffer;
}

pub fn uIntToNullTermString(input: u32) [32]u8 {
    var text_buffer: [32]u8 = undefined;
    const bytes_written = std.fmt.bufPrint(text_buffer[0..], "{}", .{input}) catch unreachable;
    text_buffer[bytes_written.len] = 0;
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
    direction: rl.Vector2,
    base_speed: f32,
    speed: f32,
    rotation: f32,
    scale: f32,
    body: [6]rl.Vector2,

    fn init(self: *@This()) void {
        //self.body = ship_shape;
        self.scale = 2;
        self.base_speed = 3;
        self.speed = 3;
        self.rotation = rl.PI / 2;
        self.direction = .{ .x = 0.0, .y = 0 };
        self.position = .{ .x = 400, .y = 200 };
    }

    fn update(self: *@This()) void {
        self.position = rl.Vector2Add(self.position, self.direction);
        std.debug.print("\nDirection x : {} | y : {}", .{ self.direction.x, self.direction.y });

        // TODO : correct passing direction to projectiles

        // Boundaries checking
        if (self.position.x < FRAME_OFFSET + 5 * self.scale) {
            self.position.x = FRAME_OFFSET + 5 * self.scale;
        } else if (self.position.x > FRAME_OFFSET + FRAME_WIDTH - 5 * self.scale) {
            self.position.x = FRAME_OFFSET + FRAME_WIDTH - 5 * self.scale;
        }
        if (self.position.y < FRAME_OFFSET + 5 * self.scale) {
            self.position.y = FRAME_OFFSET + 5 * self.scale;
        } else if (self.position.y > FRAME_OFFSET + FRAME_HEIGHT - 5 * self.scale) {
            self.position.y = FRAME_OFFSET + FRAME_HEIGHT - 5 * self.scale;
        }

        self.body = ship_shape;
        transformRLV2Slice(self.body[0..], self.scale, self.rotation, self.position);
    }
};

const enemy_shape: [5]rl.Vector2 = .{
    .{ .x = -5, .y = -5 },
    .{ .x = -5, .y = 5 },
    .{ .x = 5, .y = 5 },
    .{ .x = 5, .y = -5 },
    .{ .x = -5, .y = -5 },
};

const Enemy = struct {
    position: rl.Vector2,
    direction: rl.Vector2,
    speed: f32,
    rotation: f32,
    scale: f32,
    body: [5]rl.Vector2,

    fn init() Enemy {
        return .{
            .scale = 1,
            .speed = 1 + rand.float(f32) * 5,
            .rotation = rand.float(f32) * 2 * rl.PI,
            .direction = rl.Vector2Normalize(.{ .x = 2 * (0.5 - rand.float(f32)), .y = 2 * (0.5 - rand.float(f32)) }),
            .position = .{ .x = FRAME_OFFSET + (FRAME_WIDTH * rand.float(f32)), .y = FRAME_OFFSET + (FRAME_HEIGHT * rand.float(f32)) },
            .body = enemy_shape,
        };
    }

    fn reset(self: *@This()) void {
        self.scale = 1;
        self.speed = 1 + rand.float(f32) * 5;
        self.rotation = rand.float(f32) * 2 * rl.PI;
        self.direction = rl.Vector2Normalize(.{ .x = 2 * (0.5 - rand.float(f32)), .y = 2 * (0.5 - rand.float(f32)) });
        self.position = .{ .x = FRAME_OFFSET + (FRAME_WIDTH * rand.float(f32)), .y = FRAME_OFFSET + (FRAME_HEIGHT * rand.float(f32)) };
        self.body = enemy_shape;
    }

    fn update(self: *@This()) void {
        self.position = rl.Vector2Add(self.position, self.direction);

        // TODO : Boundaries checking external ?
        if (self.position.x < FRAME_OFFSET + 5 * self.scale or self.position.x > FRAME_OFFSET + FRAME_WIDTH - 5 * self.scale or self.position.y < FRAME_OFFSET + 5 * self.scale or self.position.y > FRAME_OFFSET + FRAME_HEIGHT - 5 * self.scale) {
            self.reset();
        }

        self.body = enemy_shape;
        transformRLV2Slice(self.body[0..], self.scale, self.rotation, self.position);
    }
};

const projectile_shape: [5]rl.Vector2 = .{
    .{ .x = -5, .y = -1 },
    .{ .x = -5, .y = 1 },
    .{ .x = 5, .y = 1 },
    .{ .x = 5, .y = -1 },
    .{ .x = -5, .y = -1 },
};

const Projectile = struct {
    position: rl.Vector2,
    direction: rl.Vector2,
    speed: f32,
    rotation: f32,
    scale: f32,
    body: [5]rl.Vector2,

    fn initFromShip(ship: *const Ship) Projectile {
        return .{
            .scale = 2,
            .speed = 6,
            .rotation = ship.rotation,
            .direction = ship.direction,
            .position = ship.position,
            .body = projectile_shape,
        };
    }

    fn update(self: *@This()) void {
        self.position = rl.Vector2Add(self.position, self.direction);

        // TODO : Boundaries checking to delete
        // if (self.position.x < FRAME_OFFSET + 5 * self.scale or self.position.x > FRAME_OFFSET + FRAME_WIDTH - 5 * self.scale or self.position.y < FRAME_OFFSET + 5 * self.scale or self.position.y > FRAME_OFFSET + FRAME_HEIGHT - 5 * self.scale) {
        //     self.reset();
        // }

        self.body = projectile_shape;
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
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello");
    defer rl.CloseWindow();
    rl.SetTargetFPS(TARGET_FPS);
    var fps: u32 = 0;

    var frame_count: u32 = 0;
    var enemy_count: u32 = 0;

    var ship: Ship = undefined;
    ship.init();

    var enemies = std.ArrayList(Enemy).init(globAlloc);
    defer enemies.deinit();

    var projectiles = std.ArrayList(Projectile).init(globAlloc);
    defer projectiles.deinit();

    var proj_to_erase = std.ArrayList(usize).init(globAlloc);
    defer proj_to_erase.deinit();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();

        frame_count += 1;

        var x: f32 = 0;
        var y: f32 = 0;

        if (rl.IsKeyDown(rl.KEY_UP)) {
            y -= 1;
        }
        if (rl.IsKeyDown(rl.KEY_DOWN)) {
            y += 1;
        }
        if (rl.IsKeyDown(rl.KEY_RIGHT)) {
            x += 1;
        }
        if (rl.IsKeyDown(rl.KEY_LEFT)) {
            x -= 1;
        }

        if (x == 0 and y == 0) {
            ship.speed = 0;
        } else {
            ship.speed = ship.base_speed;
            ship.direction = .{ .x = x, .y = y };
        }

        // TODO : finish implementing separation between speed and direction
        // Inputs : => temp_direction => Rotation
        // Update : => Rotation => Direction(normalized) => Movement (Direction x Speed)
        // Never calculate ship.direction before rotation

        if (0 == rl.Vector2Equals(ship.direction, rl.Vector2Zero())) {
            ship.direction = rl.Vector2Normalize(ship.direction);
            ship.rotation = rl.Vector2Angle(rl.Vector2{ .x = 1, .y = 0 }, ship.direction);
            ship.direction = rl.Vector2Scale(ship.direction, ship.speed);
        }

        rl.ClearBackground(rl.BLACK);

        ship.update();
        rl.DrawLineStrip(&ship.body, ship.body.len, rl.BLUE);

        if (frame_count % (TARGET_FPS / 12) == 0) { // Spawn an enemy every second
            if (rl.IsKeyDown(rl.KEY_SPACE)) {
                try projectiles.append(Projectile.initFromShip(&ship));
            }
        }

        if (frame_count % (TARGET_FPS) == 0) { // Spawn an enemy every second
            try enemies.append(Enemy.init());
            enemy_count += 1;
        }

        for (enemies.items) |*enemy| {
            enemy.update();
            rl.DrawLineStrip(&enemy.body, enemy.body.len, rl.WHITE);
        }

        proj_to_erase.clearRetainingCapacity();
        for (projectiles.items, 0..) |*projectile, i| {
            projectile.update();
            rl.DrawLineStrip(&projectile.body, projectile.body.len, rl.RED);
            if (projectile.position.x < FRAME_OFFSET or projectile.position.x > FRAME_OFFSET + FRAME_WIDTH or projectile.position.y < FRAME_OFFSET or projectile.position.y > FRAME_OFFSET + FRAME_HEIGHT) {
                try proj_to_erase.append(i);
            }
        }

        var i: usize = proj_to_erase.items.len;
        while (i > 0) {
            i -= 1;
            const index = proj_to_erase.items[i];
            _ = projectiles.orderedRemove(index);
        }

        rl.DrawRectangleLines(FRAME_OFFSET, FRAME_OFFSET, FRAME_WIDTH, FRAME_HEIGHT, rl.WHITE);
        rl.DrawText("Score : ", WINDOW_WIDTH - MENU_WIDTH + 20, 20, 20, rl.WHITE);

        rl.DrawText("FPS : ", WINDOW_WIDTH - MENU_WIDTH + 20, 60, 20, rl.WHITE);
        fps = @intCast(rl.GetFPS());
        rl.DrawText(&uIntToNullTermString(fps)[0], WINDOW_WIDTH - MENU_WIDTH + 80, 60, 20, rl.WHITE);

        rl.DrawText("Enemy COUNT : ", WINDOW_WIDTH - MENU_WIDTH + 20, 100, 20, rl.WHITE);
        rl.DrawText(&uIntToNullTermString(enemy_count)[0], WINDOW_WIDTH - MENU_WIDTH + 150, 140, 20, rl.WHITE);
    }
}
