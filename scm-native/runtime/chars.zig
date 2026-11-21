//! Character classification and case mapping over the generated Unicode
//! tables (unicode.zig, from tools/gen-unicode.scm).
//!
//! The predicates follow the JVM implementation (java.lang.Character):
//! alphabetic, upper and lower case are the derived Unicode properties,
//! numeric is category Nd, whitespace is Character.isWhitespace (the space
//! separators other than the no-break spaces, the line and paragraph
//! separators, \t \n \v \f \r and U+001C..U+001F). Case mappings are the
//! simple mappings; foldcase is the Unicode simple case folding.
const u = @import("unicode.zig");

pub const Category = u.Category;

/// The index of the last entry of the sorted table lo with lo[i] <= cp
fn floorIndex(lo: []const u21, cp: u21) ?usize {
    var a: usize = 0;
    var b: usize = lo.len;
    while (a < b) {
        const m = (a + b) / 2;
        if (lo[m] <= cp) a = m + 1 else b = m;
    }
    return if (a == 0) null else a - 1;
}

fn inRanges(lo: []const u21, hi: []const u21, cp: u21) bool {
    const i = floorIndex(lo, cp) orelse return false;
    return cp <= hi[i];
}

fn mapped(from: []const u21, to: []const u21, cp: u21) u21 {
    const i = floorIndex(from, cp) orelse return cp;
    return if (from[i] == cp) to[i] else cp;
}

pub fn category(cp: u21) Category {
    const i = floorIndex(&u.category_lo, cp) orelse return .Cn;
    return if (cp <= u.category_hi[i]) @enumFromInt(u.category_of[i]) else .Cn;
}

pub fn isDigit(cp: u21) bool {
    if (cp < 128) return cp >= '0' and cp <= '9';
    return category(cp) == .Nd;
}

pub fn digitValue(cp: u21) ?u8 {
    if (cp < 128) return if (cp >= '0' and cp <= '9') @intCast(cp - '0') else null;
    const i = floorIndex(&u.digit_from, cp) orelse return null;
    return if (u.digit_from[i] == cp) u.digit_value[i] else null;
}

pub fn isWhitespace(cp: u21) bool {
    return switch (cp) {
        '\t', '\n', 0x0B, 0x0C, '\r', 0x1C...0x1F, ' ' => true,
        0x00A0, 0x2007, 0x202F => false,
        else => cp > 127 and switch (category(cp)) {
            .Zs, .Zl, .Zp => true,
            else => false,
        },
    };
}

pub fn isUpper(cp: u21) bool {
    if (cp < 128) return cp >= 'A' and cp <= 'Z';
    return inRanges(&u.uppercase_lo, &u.uppercase_hi, cp);
}

pub fn isLower(cp: u21) bool {
    if (cp < 128) return cp >= 'a' and cp <= 'z';
    return inRanges(&u.lowercase_lo, &u.lowercase_hi, cp);
}

pub fn isAlphabetic(cp: u21) bool {
    if (cp < 128) return (cp >= 'a' and cp <= 'z') or (cp >= 'A' and cp <= 'Z');
    return inRanges(&u.alphabetic_lo, &u.alphabetic_hi, cp);
}

pub fn upcase(cp: u21) u21 {
    if (cp < 128) return if (cp >= 'a' and cp <= 'z') cp - 32 else cp;
    return mapped(&u.upper_from, &u.upper_to, cp);
}

pub fn downcase(cp: u21) u21 {
    if (cp < 128) return if (cp >= 'A' and cp <= 'Z') cp + 32 else cp;
    return mapped(&u.lower_from, &u.lower_to, cp);
}

pub fn foldcase(cp: u21) u21 {
    if (cp < 128) return if (cp >= 'A' and cp <= 'Z') cp + 32 else cp;
    return mapped(&u.fold_from, &u.fold_to, cp);
}

// --- display width (as the JVM implementation's CharWidth, after wcwidth(3)) ---------

/// East Asian Wide / Fullwidth ranges and wide emoji (inclusive pairs)
const wide = [_]u21{
    0x1100,  0x115F,  0x231A,  0x231B,  0x2329,  0x232A,  0x23E9,  0x23EC,  0x23F0,  0x23F0,
    0x23F3,  0x23F3,  0x25FD,  0x25FE,  0x2614,  0x2615,  0x2648,  0x2653,  0x267F,  0x267F,
    0x2693,  0x2693,  0x26A1,  0x26A1,  0x26AA,  0x26AB,  0x26BD,  0x26BE,  0x26C4,  0x26C5,
    0x26CE,  0x26CE,  0x26D4,  0x26D4,  0x26EA,  0x26EA,  0x26F2,  0x26F3,  0x26F5,  0x26F5,
    0x26FA,  0x26FA,  0x26FD,  0x26FD,  0x2705,  0x2705,  0x270A,  0x270B,  0x2728,  0x2728,
    0x274C,  0x274C,  0x274E,  0x274E,  0x2753,  0x2755,  0x2757,  0x2757,  0x2795,  0x2797,
    0x27B0,  0x27B0,  0x27BF,  0x27BF,  0x2B1B,  0x2B1C,  0x2B50,  0x2B50,  0x2B55,  0x2B55,
    0x2E80,  0x303E,  0x3041,  0x33FF,  0x3400,  0x4DBF,  0x4E00,  0x9FFF,  0xA000,  0xA4CF,
    0xA960,  0xA97F,  0xAC00,  0xD7A3,  0xF900,  0xFAFF,  0xFE10,  0xFE19,  0xFE30,  0xFE6F,
    0xFF00,  0xFF60,  0xFFE0,  0xFFE6,  0x16FE0, 0x16FE4, 0x17000, 0x18AFF, 0x1B000, 0x1B2FF,
    0x1F004, 0x1F004, 0x1F0CF, 0x1F0CF, 0x1F18E, 0x1F18E, 0x1F191, 0x1F19A, 0x1F200, 0x1F202,
    0x1F210, 0x1F23B, 0x1F240, 0x1F248, 0x1F250, 0x1F251, 0x1F260, 0x1F265, 0x1F300, 0x1F320,
    0x1F32D, 0x1F335, 0x1F337, 0x1F37C, 0x1F37E, 0x1F393, 0x1F3A0, 0x1F3CA, 0x1F3CF, 0x1F3D3,
    0x1F3E0, 0x1F3F0, 0x1F3F4, 0x1F3F4, 0x1F3F8, 0x1F43E, 0x1F440, 0x1F440, 0x1F442, 0x1F4FC,
    0x1F4FF, 0x1F53D, 0x1F54B, 0x1F54E, 0x1F550, 0x1F567, 0x1F57A, 0x1F57A, 0x1F595, 0x1F596,
    0x1F5A4, 0x1F5A4, 0x1F5FB, 0x1F64F, 0x1F680, 0x1F6C5, 0x1F6CC, 0x1F6CC, 0x1F6D0, 0x1F6D2,
    0x1F6D5, 0x1F6D7, 0x1F6DC, 0x1F6DF, 0x1F6EB, 0x1F6EC, 0x1F6F4, 0x1F6FC, 0x1F7E0, 0x1F7EB,
    0x1F7F0, 0x1F7F0, 0x1F90C, 0x1F93A, 0x1F93C, 0x1F945, 0x1F947, 0x1F9FF, 0x1FA70, 0x1FAFF,
    0x20000, 0x2FFFD, 0x30000, 0x3FFFD,
};

fn inWide(cp: u21) bool {
    var lo: usize = 0;
    var hi: usize = wide.len / 2;
    while (lo < hi) {
        const mid = (lo + hi) / 2;
        if (cp < wide[2 * mid]) {
            hi = mid;
        } else if (cp > wide[2 * mid + 1]) {
            lo = mid + 1;
        } else return true;
    }
    return false;
}

/// -1 for control characters, 0 for combining, format and zero-width
/// characters, 2 for wide characters, else 1
pub fn width(cp: u21) i8 {
    if (cp == 0) return 0;
    if (cp < 32 or (cp >= 0x7F and cp < 0xA0)) return -1;
    if (cp < 0x300) return 1;
    if (cp >= 0xD800 and cp <= 0xDFFF) return 1;
    if ((cp >= 0x1160 and cp <= 0x11FF) or cp == 0x200B) return 0;
    return switch (category(cp)) {
        .Mn, .Me, .Cf => 0,
        else => if (inWide(cp)) 2 else 1,
    };
}
