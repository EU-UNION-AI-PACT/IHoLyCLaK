#!/bin/bash
# 33x 16PB Sparse-Images als XFS, automatisch gemountet

set -e

COUNT=33
SIZE="16P"
IMGDIR="/var/vdisks"
POOLDIR="/mnt/petabyte-pool"

pacman -Syu --noconfirm xfsprogs util-linux

mkdir -p "$IMGDIR"
mkdir -p "$POOLDIR"

for i in $(seq -w 1 $COUNT); do
  IMG="$IMGDIR/pb${i}.img"
  MNT="$POOLDIR/pb${i}"

  # Image nur anlegen, wenn nicht vorhanden
  if [[ ! -f "$IMG" ]]; then
    echo "Erstelle Sparse-Image $IMG ..."
    fallocate -l $SIZE "$IMG"
  fi

  # Loopback-Device zuweisen (findet schon bestehendes oder neues)
  LOOPDEV=$(losetup -j "$IMG" | awk -F: '{print $1}')
  if [[ -z "$LOOPDEV" ]]; then
    LOOPDEV=$(losetup -f --show "$IMG")
  fi

  # Falls noch kein Dateisystem drauf: formatieren
  if ! blkid "$LOOPDEV" | grep -q xfs; then
    echo "Formatiere $LOOPDEV mit XFS ..."
    mkfs.xfs -f "$LOOPDEV"
  fi

  mkdir -p "$MNT"

  # In /etc/fstab eintragen, falls noch nicht vorhanden (über UUID)
  UUID=$(blkid -s UUID -o value "$LOOPDEV")
  FSTABLINE="UUID=$UUID $MNT xfs defaults 0 0"
  if ! grep -q "$UUID" /etc/fstab ; then
    echo "$FSTABLINE" >> /etc/fstab
  fi

  # Mounten nur wenn noch nicht gemountet
  if ! mount | grep -q "$MNT"; then
    mount "$MNT"
    echo "$MNT bereit!"
  else
    echo "$MNT ist schon gemountet."
  fi
done

echo "Fertig! Alle $COUNT 16PB-Volumes unter $POOLDIR."
df -h | grep "$POOLDIR"
