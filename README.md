# md2html
Markdownファイルを読み取り、HTMLファイルに変換する変換器
zig-0.14.0対応
## インストール
```bash
git clone https://github.com/yamada031016/md2html.git
or
zig fetch --save=md2html https://github.com/yamada031016/md2html/archive/refs/heads/main.tar.gz
```

## 使い方
以下はMarkdownファイルをHTMLファイルに変換し、htmlディレクトリに配置する例です。
```bash
zig build run -- <markdown_files_directory>
```
or
```zig
zig build run -- <markdown_files_directory>
```

## 対応状況
