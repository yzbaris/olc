const std = @import("std");
const rl = @import("raylib");
const loader = @import("loader.zig");
const common = @import("common.zig");

const Vec2 = common.Vec2;

const SPREADSHEET_PATH = "assets/round.png";
const SPREADSHEET_DESC_PATH = "assets/round.xml";

const AnimalKind = enum { bear, buffalo, chick, chicken, cow, crocodile, dog, duck, elephant, frog, giraffe, goat, gorilla, hippo, horse, monkey, moose, narwhal, owl, panda, parrot, penguin, pig, rabbit, rhino, sloth, snake, walrus, whale, zebra };
const SpriteSheet = struct {
    texture: rl.Texture2D,
    rects: std.AutoHashMap(AnimalKind, rl.Rectangle),

    pub fn load(allocator: std.mem.Allocator, io: std.Io) !SpriteSheet {
        const xml_buffer = try allocator.alloc(u8, 1024 * 1024);
        defer allocator.free(xml_buffer);
        const xml_file = try std.Io.Dir.readFile(std.Io.Dir.cwd(), io, SPREADSHEET_DESC_PATH, xml_buffer);
        var kenney_xml = try loader.parse_kenney_xml(allocator, xml_file);
        defer kenney_xml.deinit();

        var sheet: SpriteSheet = .{
            .texture = try rl.loadTexture(SPREADSHEET_PATH),
            .rects = .init(allocator),
        };
        errdefer sheet.deinit();

        var iter = kenney_xml.iterator();

        while (iter.next()) |entry| {
            try sheet.rects.put(try parse(entry.key_ptr.*), entry.value_ptr.*);
        }

        return sheet;
    }

    pub fn get_rect(self: *SpriteSheet, kind: AnimalKind) !rl.Rectangle {
        return self.rects.get(kind) orelse return error.RectangleNotFound;
    }

    pub fn parse(str: []const u8) !AnimalKind {
        return std.meta.stringToEnum(AnimalKind, str) orelse error.InvalidAnimalKind;
    }

    pub fn deinit(self: *SpriteSheet) void {
        self.rects.deinit();
        rl.unloadTexture(self.texture);
    }
};

const Sprite = struct {
    rect: rl.Rectangle,
    _origin: Vec2 = .zero(),
    rotation: f32 = 0,
    scale: f32 = 0.5,
    source_sheet: *SpriteSheet,
    _collision_rad: f32,

    pub fn init(rect: rl.Rectangle, source: *SpriteSheet) Sprite {
        return .{
            .rect = rect,
            .source_sheet = source,
            ._collision_rad = @min(rect.height, rect.width) / 2,
            ._origin = .init(rect.width / 2, rect.height / 2),
        };
    }

    pub fn render(self: *Sprite, pos: Vec2) void {
        rl.drawTexturePro(
            self.source_sheet.texture,
            self.rect,
            self.get_target_rect(pos),
            self.get_origin().to_rl(),
            self.rotation,
            rl.Color.white,
        );
    }

    pub fn get_target_rect(self: *Sprite, pos: Vec2) rl.Rectangle {
        return rl.Rectangle{
            .x = pos.x,
            .y = pos.y,
            .width = self.rect.width * self.scale,
            .height = self.rect.height * self.scale,
        };
    }

    pub fn get_origin(self: *Sprite) Vec2 {
        return self._origin.scale(self.scale);
    }

    pub fn get_collision_rad(self: *Sprite) f32 {
        return self._collision_rad * self.scale;
    }
};

const AnimalProperties = struct {
    max_speed: f32 = 20,
    acc: f32 = 20,
    deacc: f32 = 22,
};

const Animal = struct {
    id: i32,
    kind: AnimalKind,
    sprite: Sprite,
    pos: Vec2 = .zero(),
    velocity: Vec2 = .zero(),
    dir: Vec2 = .zero(),
    speed: f32 = 0,
    props: AnimalProperties = .{},
    is_colliding: bool = false,
    is_player_controlled: bool = false,

    pub fn init(kind: AnimalKind, id: i32, sheet: *SpriteSheet) !Animal {
        return .{ .kind = kind, .id = id, .sprite = .init(try sheet.get_rect(kind), sheet) };
    }

    pub fn update(self: *Animal, dt: f32) void {
        if (self.is_colliding) return;

        if (self.dir.is_zero()) {
            self.velocity = Vec2.move_toward(self.velocity, .zero(), self.props.deacc * dt);
        } else {
            self.velocity = Vec2.move_toward(self.velocity, self.dir.scale(self.props.max_speed), self.props.acc * dt);
        }
        self.pos = self.pos.add(self.velocity.scale(dt));
    }

    pub fn render(self: *Animal) void {
        self.sprite.render(self.pos);
    }

    pub fn check_collision(self: *Animal, other: *Animal) bool {
        if (self.id == other.id) return false;

        const combined = self.sprite.get_collision_rad() + other.sprite.get_collision_rad();
        const distance = self.pos.dist(other.pos);

        if (distance < combined) {
            const dir_away = self.pos.sub(other.pos).normalized();
            if (self.dir.dot(dir_away) <= 0.0) {
                self.velocity = .zero();
                return true;
            }
        }

        return false;
    }
};

const PlayerController = struct {
    animal: *Animal,

    pub fn init(animal: *Animal) PlayerController {
        animal.is_player_controlled = true;
        return .{ .animal = animal };
    }

    pub fn update(self: *PlayerController) void {
        var move_dir: Vec2 = .zero();

        if (rl.isKeyDown(.w)) {
            move_dir.addy(-1);
        }
        if (rl.isKeyDown(.s)) {
            move_dir.addy(1);
        }
        if (rl.isKeyDown(.a)) {
            move_dir.addx(-1);
        }
        if (rl.isKeyDown(.d)) {
            move_dir.addx(1);
        }

        self.animal.dir = move_dir.normalized();
    }
};

const AIControlled = struct {
    animal: *Animal,
    _next_check_time: f64,

    pub fn init(animal: *Animal) AIControlled {
        return .{ .animal = animal, ._next_check_time = rl.getTime() };
    }
};

const AIController = struct {
    controlleds: std.ArrayList(AIControlled),
    rand: std.Random,

    // will be deinited outside
    pub fn init(rand: std.Random) AIController {
        return .{
            .controlleds = .empty,
            .rand = rand,
        };
    }

    pub fn update(self: *AIController, _: f32) void {
        const curr_time = rl.getTime();
        for (self.controlleds.items) |*controlled| {
            if (controlled.animal.is_colliding or curr_time >= controlled._next_check_time) {
                const dirx: f32 = @floatFromInt(self.rand.intRangeAtMost(i32, -1, 1));
                const diry: f32 = @floatFromInt(self.rand.intRangeAtMost(i32, -1, 1));
                controlled.animal.dir = .init(dirx, diry);
                controlled._next_check_time = curr_time + 0.5 + self.rand.float(f32) * 5;
            }
        }
    }
};

const Game = struct {
    allocator: std.mem.Allocator,
    random: std.Random,
    _next_id: i32,
    animals: std.AutoHashMap(i32, Animal),
    spritesheet: SpriteSheet,
    player: PlayerController,
    ai_controller: AIController,
    debug: bool = false,

    pub fn load(allocator: std.mem.Allocator, io: std.Io, rand: std.Random) !Game {
        return .{
            .allocator = allocator,
            .player = .{ .animal = undefined },
            .ai_controller = .init(rand),
            .random = rand,
            .animals = .init(allocator),
            .spritesheet = try SpriteSheet.load(allocator, io),
            ._next_id = 1,
        };
    }

    pub fn start(self: *Game) !void {
        inline for (std.meta.tags(AnimalKind)) |kind| {
            _ = try self.spawn(kind);
        }

        const player_id = 1;

        var iter = self.animals.valueIterator();
        var padding: f32 = 50;
        while (iter.next()) |animal| {
            if (animal.id == player_id) {
                self.player = .init(try self.get_animal(player_id));
                animal.pos = .init(400, 0);
            } else {
                try self.ai_controller.controlleds.append(self.allocator, .init(animal));
                animal.pos = .init(padding, padding);
            }
            padding += 60;
        }
    }

    pub fn update(self: *Game, dt: f32) void {
        self.player.update();
        self.ai_controller.update(dt);
        var update_iter = self.animals.valueIterator();
        while (update_iter.next()) |animal| {
            var others = self.animals.valueIterator();

            animal.is_colliding = false;
            while (others.next()) |other| {
                if (animal.check_collision(other)) {
                    animal.is_colliding = true;
                    break;
                }
            }
            animal.update(dt);
        }
    }

    pub fn render(self: *Game) void {
        var render_iter = self.animals.valueIterator();
        while (render_iter.next()) |animal| {
            if (self.debug) rl.drawRectangleRec(animal.sprite.get_target_rect(animal.pos.sub(animal.sprite.get_origin())), .white);
            if (self.debug) rl.drawCircleV(animal.pos.to_rl(), animal.sprite.get_collision_rad(), .green);
            animal.render();
        }
    }

    pub fn deinit(self: *Game) void {
        self.animals.deinit();
        self.spritesheet.deinit();
        self.ai_controller.controlleds.deinit(self.allocator);
    }

    pub fn _gen_id(self: *Game) i32 {
        const curr_id = self._next_id;
        self._next_id += 1;

        return curr_id;
    }

    pub fn spawn(self: *Game, kind: AnimalKind) !i32 {
        const curr_id = self._gen_id();
        try self.animals.put(curr_id, try .init(kind, curr_id, &self.spritesheet));
        return curr_id;
    }

    pub fn get_animal(self: *Game, id: i32) !*Animal {
        return self.animals.getPtr(id) orelse return error.AnimalNotExist;
    }
};

pub fn main(init: std.process.Init) anyerror!void {
    const allocator = init.gpa;

    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "Animal Framing");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var random_source: std.Random.IoSource = .{
        .io = init.io,
    };

    var game: Game = try .load(allocator, init.io, random_source.interface());
    defer game.deinit();

    try game.start();

    while (!rl.windowShouldClose()) {
        game.update(rl.getFrameTime());

        if (rl.isKeyPressed(.h)) game.debug = !game.debug;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.blue);

        game.render();
    }
}
