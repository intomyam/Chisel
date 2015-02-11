# Chisel

Chiselは、xv6ファイルイメージのチェッカーです。

Chisel(鑿) is xv6's file system disc image (fs.img) checker.

## Check

```bash
$ ruby chisel.rb fs/fs.img
```

ディレクトリ内の全てのimgを再帰的にチェックすることもできます

```bash
$ ruby chisel.rb -r fs
```

## Console

コンソールモードを使ってイメージファイルの中身を見ることができます

```bash
$ ruby chisel.rb -c fs/fs.img
[Chisel:console /]$
```

コマンド

* ls [-p]
* cd [name]
* stat [name]