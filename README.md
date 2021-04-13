# rtl8187 + Master Mode + Packet Injection

This repository contains everything you need to use a realtek chipset based wifi adapter with hostapd in master mode.

(◑○◑)

Yes, I was wrong ... the coordinates, I was born on the wrong planet.

( °-°)シ ミ★ ミ☆

## Features

Patch the linux wireless [backports](https://backports.wiki.kernel.org/index.php/Main_Page) to enable:

* Master mode
* Packet Injection

for *rtl8187* based wifi adapters (tested with *hostapd*).

## Building

1 . You need clone this repository:

```sh
git clone https://github.com/matrix/backports-rtl8187
```

2 . Proceed to build *backports-rtl8187*:

```sh
./build.sh -b
```

3 . Now you can install *backports-rtl8187*:

```sh
./build.sh -i
```

## Notes

If you want, you can uninstall *backports-rtl8187* by using the script:

```sh
./build.sh -u
```

If you want cleanup the workdir tree:

```sh
./build.sh -c
```

**That's all folks** 😉
