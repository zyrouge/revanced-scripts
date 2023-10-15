# Revanced Scripts

Script to easily build ReVanced APKs.

## Usage

0. Have [Git](https://git-scm.com/) and [OpenJDK 21](https://jdk.java.net/21/) installed.

1. Clone this repository.

```bash
git clone https://github.com/zyrouge/revanced-scripts.git
cd revanced-scripts
```

2. Use `pack.sh` for building APKs.
You might also need `chmod +x ./pack.sh`.

```bash
./pack.sh <app-id>
```

### Examples

```bash
./pack.sh -h
./pack.sh com.google.android.youtube
./pack.sh -j ~/TPBinaries/jdk-21/bin/java com.google.android.youtube
```

## License

[Unlicense](./LICENSE)
