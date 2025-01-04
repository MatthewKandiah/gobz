const Pos = @import("pos.zig").Pos;
const EnemyType = @import("enemy_type.zig").EnemyType;
const EnemyRace = @import("enemy_race.zig").EnemyRace;

pub const EnemyState = struct {
    pos: Pos,
    type: EnemyType,
    race: EnemyRace,
    max_health: f32,
    current_health: f32,
};
