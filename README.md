# d3face

Tool deface website untuk Termux. Bash + curl, tanpa Python.

## Pasang

```bash
pkg install curl bash -y
bash <(curl -fsSL https://raw.githubusercontent.com/USER/d3face/main/install.sh)
```

Setelah itu cukup:

```bash
d3face
```

Tanpa memasang permanen:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USER/d3face/main/d3face.sh)
```

## Pakai

Menu interaktif:

```
1  recon
2  deface
3  restore
4  pengaturan
```

Langsung tanpa menu:

```bash
d3face -d target.com -m ftp -u user -p pass -P /public_html -y
d3face -d target.com -m auto -y
d3face -l domains.txt -m ftp -u user -p pass -y
```

Metode: `ftp`, `sftp`, `webdav`, `put`, `cpanel`, `auto`.
Backup otomatis ke `~/.config/d3face/backups/`.

## Metode mana?

| Kondisi | Metode |
|---|---|
| port 21 terbuka | `ftp` |
| punya login cPanel | `cpanel` |
| WordPress admin | upload tema manual |
| tidak tahu | `auto` |

## Lisensi

MIT