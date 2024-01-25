CC=gcc
CFLAGS=-march=x86-64 -O2 -Wall
JOBS=$(shell nproc)

# VERSIONS

KERNEL=6.6.12
MUSL=1.2.4

download: download_kernel download_musl
build: create_img create_initramfs build_musl build_init build_kernel cp_initramfs build_iso

# KERNEL

download_kernel:
	rm -rf "linux-kernel"
	curl "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/snapshot/linux-$(KERNEL).tar.gz" -o "linux.tar.gz"
	tar -zxf "linux.tar.gz"
	rm "linux.tar.gz"
	mkdir -p sources
	mv "linux-$(KERNEL)" "sources/linux-kernel"

build_kernel:
	cp config/linux.config sources/linux-kernel/.config
	cd sources/linux-kernel && \
	make "-j$(JOBS)" && \
	INSTALL_PATH=../../build/mnt/boot make install
	rm -rf build/mnt/boot/*.old

# MUSL

download_musl:
	rm -rf "musl"
	curl "https://musl.libc.org/releases/musl-$(MUSL).tar.gz" -o "musl.tar.gz"
	tar -zxf "musl.tar.gz"
	rm "musl.tar.gz"
	mkdir -p sources
	mv "musl-$(MUSL)" "sources/musl"

build_musl:
	cd sources/musl && \
	mkdir -p ../../build/initramfs/usr/local/musl && \
	./configure --prefix=../../build/initramfs --syslibdir=../../build/initramfs/lib x86_64 && \
	make "-j$(JOBS)" && \
	make install && \
	cp ../../build/initramfs/lib/musl-gcc.specs ../../build/musl-gcc-init.specs && \
	sed -i 's/\.\.\/\.\.\//..\//g' ../../build/musl-gcc-init.specs


# INITRAMFS

create_initramfs:
	mkdir -p build/initramfs
	cp -r initramfs/* build/initramfs
	mknod -m 622 build/initramfs/dev/console c 5 1 |:
	mknod -m 622 build/initramfs/dev/tty0 c 4 0 |:

cp_initramfs:
	cp sources/linux-kernel/usr/initramfs_data.cpio "build/mnt/boot/initramfs-$(KERNEL).img"

# INIT

build_init:
	@$(MAKE) -C init -f init.mk
	cp init/init build/initramfs/etc

# ISO

create_img:
	mkdir -p build/mnt/boot/efi build/mnt/boot/grub
	cp config/grub.cfg build/mnt/boot/grub
	sed -i "s/VERSION/$(KERNEL)/g" build/mnt/boot/grub/grub.cfg

build_iso:
	grub-mkrescue -o Cloak.iso build/mnt

clean:
	cd sources/linux-kernel && make clean
	cd sources/musl && make clean
	rm -rf build
