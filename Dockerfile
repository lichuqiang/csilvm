FROM golang:1.9.2

RUN apt-get update && \
    apt-get install -y strace less nano xfsprogs udev

RUN mkdir /build && \
	cd /build && \
	wget http://mirrors.kernel.org/sourceware/lvm2/releases/LVM2.2.02.176.tgz && \
	tar -xzvf LVM2.2.02.176.tgz && \
	cd LVM2.2.02.176 && \
	./configure --enable-applib && \
	make -j8 && \
	make install

RUN mkdir -p /go/src/github.com/alecthomas && \
    cd /go/src/github.com/alecthomas && \
    git clone https://github.com/alecthomas/gometalinter.git --branch=v1.2.1 && \
    go install -v github.com/alecthomas/gometalinter && \
    gometalinter --install && \
    go get -u golang.org/x/tools/cmd/goimports && \
    mkdir -p /go/src/github.com/mesosphere/csilvm

RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/' /etc/lvm/lvm.conf

WORKDIR /go/src/github.com/mesosphere/csilvm
