const std = @import("std");
const mem = std.mem;

pub fn convert(data:[]u8) ![]u8 {
    var buf:[1024 * 10]u8 = undefined;
    var current:usize = 0;

    var skip:usize = 0;
    var close_tags = std.ArrayList([]const u8).init(std.heap.page_allocator);

    var in_bold = false;
    var in_italic = false;
    var in_nest = false;
    var in_code = false;
    var startNumberedList = false;

    for(data, 0..) |c, i| {
        if (skip != 0) {
            skip -= 1;
            continue;
        }
        switch(c) {
            '#' => {
                var level:usize = 1;
                for (data[i+1..]) |tmp| {
                    if(tmp != '#') {
                        break;
                    }
                    level += 1;
                }
                skip = level; // number of following # + one whitespace. level - 1 + 1
                const string = try std.fmt.allocPrint(std.heap.page_allocator, "<h{}>", .{level});
                try close_tags.append( try std.fmt.allocPrint(std.heap.page_allocator, "</h{}>", .{level}));
                @memcpy(buf[current..current+string.len], string);
                current += string.len;
            },
            '*' => {
                const string = fmt:{
                    if(mem.startsWith(u8, data[i..], "***")) {
                        const tmp = if (in_bold and in_italic) "</i></b>" else "<b><i>";
                        in_bold = !in_bold;
                        in_italic = !in_italic;
                        skip += 2;
                        break :fmt tmp;
                    } else if(mem.startsWith(u8, data[i..], "**")) {
                        const tmp = if (in_bold) "</b>" else "<b>";
                        in_bold = !in_bold;
                        skip += 1;
                        break :fmt tmp;
                    } else if(mem.startsWith(u8, data[i..], "* ")) {
                        const tmp = if(in_nest) "<ul><li style=\"list-style:circle\">" else "<li>";
                        const close_tag = if(in_nest) "</li></ul>" else "</li>";
                        try close_tags.append(close_tag);
                        break :fmt tmp;
                    } else {
                        const tmp = if (in_italic) "</i>" else "<i>";
                        in_italic = !in_italic;
                        break :fmt tmp;
                    }
                };
                @memcpy(buf[current..current+string.len], string);
                current += string.len;
            },
            '-' => {
                if(mem.startsWith(u8, data[i..], "---")) {
                    const string = "<hr>";
                    skip += 2;
                    @memcpy(buf[current..current+string.len], string);
                    current += string.len;
                } else if(mem.startsWith(u8, data[i..], "- ")) {
                    const tag = if(in_nest) "<ul><li style=\"list-style:circle\">" else "<li>";
                    const close_tag = if(in_nest) "</li></ul>" else "</li>";
                    if(in_nest) {
                        in_nest = false;
                    }
                    try close_tags.append(close_tag);
                    @memcpy(buf[current..current+tag.len], tag);
                    current += tag.len;
                } else {
                    buf[current] = c;
                    current += 1;
                }
            },
            '+' => {
                if(mem.startsWith(u8, data[i..], "+ ")) {
                    const tag = if(in_nest) "<ul><li style=\"list-style:circle\">" else "<li>";
                    const close_tag = if(in_nest) "</li></ul>" else "</li>";
                    if(in_nest) {
                        in_nest = false;
                    }
                    try close_tags.append(close_tag);
                    @memcpy(buf[current..current+tag.len], tag);
                    current += tag.len;
                } else {
                    buf[current] = c;
                    current += 1;
                }
            },
            '`' => {
                const tag = if (in_code) "</code>" else "<code>";
                in_code = !in_code;
                @memcpy(buf[current..current+tag.len], tag);
                current += tag.len;
            },
            '[' => {
                const pos = alt:{
                    for(data[i+1..], 0..) |a, j| {
                        if (a == ']') {
                            break :alt j;
                        }
                    }
                    unreachable;
                };
                const kaji_end = i+1+pos;
                const kaji_text = data[i+1..kaji_end];
                skip += pos;
                if(data.len > kaji_end+1) {
                    if (data[kaji_end+1] == '(') {
                        const src_pos = src:{
                            for(data[kaji_end+1..], 0..) |s, k| {
                                if (s == ')') {
                                    break :src k;
                                }
                            }
                            unreachable;
                        };
                        const string = try std.fmt.allocPrint(std.heap.page_allocator, "<a href=\"{s}\">{s}</a>", .{data[kaji_end+2..kaji_end+1+src_pos], kaji_text});
                        @memcpy(buf[current..current+string.len], string);
                        current += string.len;
                        skip += src_pos+2;
                    }
                }
            },
            '!' => {
                if(mem.startsWith(u8, data[i..], "![")) {
                    const alt_pos = alt:{
                        for(data[i+1..], 0..) |a, j| {
                            if (a == ']') {
                                break :alt j;
                            }
                        }
                        unreachable;
                    };
                    const alt_end = i+1+alt_pos;
                    const alt_text = data[i+1..alt_end];
                    skip += alt_pos;
                    if(data.len > alt_end+1) {
                        if (data[alt_end+1] == '(') {
                            const src_pos = src:{
                                for(data[alt_end+1..], 0..) |s, k| {
                                    if (s == ' ') {
                                        break :src k;
                                    }
                                }
                                unreachable;
                            };
                            skip += src_pos+2;
                            const title:?[]const u8  = getTitle:{
                                if (data[alt_end+src_pos+1] == ')') {
                                    break :getTitle null;
                                } else if (data[alt_end+src_pos+2] == '"'){
                                    const title_pos = title:{
                                        for(data[alt_end+src_pos+3..], 0..) |s, k| {
                                            if (s == '"') {
                                                break :title k;
                                            }
                                        }
                                        unreachable;
                                    };
                                    skip += title_pos + 3;
                                    break :getTitle data[alt_end+src_pos+1..alt_end+src_pos+1+title_pos];
                                } else {
                                    unreachable;
                                }
                            };
                            const string = try std.fmt.allocPrint(std.heap.page_allocator, "<img src=\"{s}\"alt=\"{s}\"title=\"{s}\">", .{data[alt_end+2..alt_end+1+src_pos], alt_text, title orelse ""});
                            @memcpy(buf[current..current+string.len], string);
                            current += string.len;
                        }
                    }
                }
            },
            '\t' => {
                in_nest = true;
            },
            ' ' => {
                if(mem.startsWith(u8, data[i..], "   ")) {
                    in_nest = true;
                    skip += 2;
                } else if(mem.startsWith(u8, data[i..], "  \n")) {
                    skip += 2;
                    const string = "<br>";
                    @memcpy(buf[current..current+string.len], string);
                    current += string.len;
                } else {
                    buf[current] = c;
                    current += 1;
                }
            },
            '\n' => {
                if(startNumberedList and data.len > i) {
                    const numberedList = try std.fmt.allocPrint(std.heap.page_allocator, "{}. ", .{if(data[i+1]>0x30) data[i+1]-0x30 else data[i+1]}); // char less than 0x30 can be skipped
                    if(!mem.startsWith(u8, data[i+1..], numberedList)) {
                        const tag = "</ol>";
                        @memcpy(buf[current..current+tag.len], tag);
                        current += tag.len;

                        startNumberedList = false;
                    }
                }
                while(close_tags.popOrNull()) |close| {
                    @memcpy(buf[current..current+close.len], close);
                    current += close.len;
                }
            },
            else => |char| {
                const numberedList = try std.fmt.allocPrint(std.heap.page_allocator, "{}. ", .{if(char>0x30) char-0x30 else char}); // char less than 0x30 can be skipped
                if(mem.startsWith(u8, data[i..], numberedList)) {
                    skip += numberedList.len - 1;

                    if (!startNumberedList) {
                        const tag = "<ol>";
                        @memcpy(buf[current..current+tag.len], tag);
                        current += tag.len;

                        startNumberedList = true;
                    }

                    const tag = if(in_nest) "<ol><li>" else "<li>";
                    const close_tag = if(in_nest) "</li></ol>" else "</li>";
                    if(in_nest) {
                        in_nest = false;
                    }
                    try close_tags.append(close_tag);
                    @memcpy(buf[current..current+tag.len], tag);
                    current += tag.len;
                } else {
                    buf[current] = c;
                    current += 1;
                }
            },
        }
    }
    return std.heap.page_allocator.dupe(u8,buf[0..current]) catch "";
}
