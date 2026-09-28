const std = @import("std");
const rl = @import("raylib");
const loader = @import("loader.zig");

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
    origin: rl.Vector2 = rl.Vector2.zero(),
    rotation: f32 = 0,
    scale: f32 = 1,
    source_sheet: *SpriteSheet,

    pub fn init(rect: rl.Rectangle, source: *SpriteSheet) Sprite {
        return .{
            .rect = rect,
            .source_sheet = source,
        };
    }

    pub fn render(self: *Sprite, posx: f32, posy: f32) void {
        rl.drawTexturePro(
            self.source_sheet.texture,
            self.rect,
            rl.Rectangle{
                .x = posx,
                .y = posy,
                .width = self.rect.width * self.scale,
                .height = self.rect.height * self.scale,
            },
            self.origin,
            self.rotation,
            rl.Color.white,
        );
    }
};

const Animal = struct {
    kind: AnimalKind,
    sprite: Sprite,
    posx: f32 = 0,
    posy: f32 = 0,

    pub fn init(kind: AnimalKind, sheet: *SpriteSheet) !Animal {
        return .{ .kind = kind, .sprite = .init(try sheet.get_rect(kind), sheet) };
    }

    pub fn render(self: *Animal) void {
        self.sprite.render(self.posx, self.posy);
    }
};

const Game = struct {
    allocator: std.mem.Allocator,
    _next_id: i32,
    animals: std.AutoHashMap(i32, Animal),
    spritesheet: SpriteSheet,

    pub fn load(allocator: std.mem.Allocator, io: std.Io) !Game {
        return .{
            .allocator = allocator,
            .animals = .init(allocator),
            .spritesheet = try SpriteSheet.load(allocator, io),
            ._next_id = 1,
        };
    }

    pub fn deinit(self: *Game) void {
        self.animals.deinit();
        self.spritesheet.deinit();
    }

    pub fn _gen_id(self: *Game) i32 {
        const curr_id = self._next_id;
        self._next_id += 1;

        return curr_id;
    }

    pub fn spawn(self: *Game, kind: AnimalKind) !i32 {
        const curr_id = self._gen_id();
        try self.animals.put(curr_id, try .init(kind, &self.spritesheet));
        return curr_id;
    }

    pub fn get_animal(self: *Game, id: i32) !*Animal {
        return try self.animals.get(id) orelse return error.AnimalNotExist;
    }
};

pub fn main(init: std.process.Init) anyerror!void {
    const allocator = init.gpa;

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var game: Game = try .load(allocator, init.io);
    defer game.deinit();

    inline for (std.meta.tags(AnimalKind)) |kind| {
        _ = try game.spawn(kind);
    }

    var iter = game.animals.valueIterator();
    var padding: f32 = 0;
    while (iter.next()) |animal| {
        animal.posx += padding;
        animal.posy += padding;
        padding += 30;
    }

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.blue);

        var animal_iter = game.animals.valueIterator();

        while (animal_iter.next()) |animal| {
            animal.render();
        }
    }
}
