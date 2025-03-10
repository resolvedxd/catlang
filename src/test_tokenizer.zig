const std = @import("std");
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
const TokenType = Tokenizer.TokenType;

fn tokens_equal(actual: std.ArrayList(Token), expected: []const TokenType) bool {
    if (actual.items.len != expected.len) return false;

    for (actual.items, expected) |actual_t, expected_t| {
        if (actual_t.type != expected_t) return false;
    }
    return true;
}
fn test_tokenize(str: [:0]const u8, expected: []const TokenType) !void {
    var tokenizer = Tokenizer.Tokenizer.init(str);
    var tokens = tokenizer.tokenize(std.testing.allocator);
    defer tokens.deinit();
    // for (tokens.items) |token|
    //     std.debug.print("{s}:{s}, ", .{ str[token.pos.start..token.pos.end], @tagName(token.type) });
    // std.debug.print("\n", .{});
    _ = tokens.pop();
    try std.testing.expect(tokens_equal(tokens, expected));
}

test "keywords" {
    try test_tokenize("return", &.{.keyword_return});
    try test_tokenize("if", &.{.keyword_if});
    try test_tokenize("while", &.{.keyword_while});
    try test_tokenize("for", &.{.keyword_for});
}

test "number literal" {
    try test_tokenize("1234", &.{.number_literal});
    try test_tokenize("0xff_a1_23", &.{.number_literal});
    try test_tokenize("0b00_00_01", &.{.number_literal});
    try test_tokenize("0456", &.{.number_literal});
}

test "string literal" {
    try test_tokenize("\"test if while for\"", &.{.string_literal});
}

test "variable assignment" {
    try test_tokenize("var hello: u32 = 123;", &.{ .keyword_var, .identifier, .colon, .identifier, .equal, .number_literal, .semicolon });
}

test "math" {
    try test_tokenize("1+2*3-4", &.{ .number_literal, .plus, .number_literal, .asterisk, .number_literal, .minus, .number_literal });
}

test "if" {
    try test_tokenize("if (1 == 2)", &.{ .keyword_if, .paren_left, .number_literal, .equal_equal, .number_literal, .paren_right });
    try test_tokenize("if (1 != 2)", &.{ .keyword_if, .paren_left, .number_literal, .bang_equal, .number_literal, .paren_right });
    try test_tokenize("if (1 >= 2 > 3)", &.{ .keyword_if, .paren_left, .number_literal, .greater_than_or_eq, .number_literal, .greater_than, .number_literal, .paren_right });
    try test_tokenize("if (1 <= 2 < 3)", &.{ .keyword_if, .paren_left, .number_literal, .lesser_than_or_eq, .number_literal, .lesser_than, .number_literal, .paren_right });
}
