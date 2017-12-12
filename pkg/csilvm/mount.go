package csilvm

import (
	"io/ioutil"
	"strings"
)

/*
3.5	/proc/<pid>/mountinfo - Information about mounts
--------------------------------------------------------

This file contains lines of the form:

36 35 98:0 /mnt1 /mnt2 rw,noatime master:1 - ext3 /dev/root rw,errors=continue
(1)(2)(3)   (4)   (5)      (6)      (7)   (8) (9)   (10)         (11)

753 883 253:13 /   /tmp/foo rw,relatime -   xfs   /dev/bar     rw,seclabel,attr2,inode64,noquota
(1) (2) (3)    (4) (5)      (6)  (no 7) (8) (9)   (10)         (11)


(1) mount ID:  unique identifier of the mount (may be reused after umount)
(2) parent ID:  ID of parent (or of self for the top of the mount tree)
(3) major:minor:  value of st_dev for files on filesystem
(4) root:  root of the mount within the filesystem
(5) mount point:  mount point relative to the process's root
(6) mount options:  per mount options
(7) optional fields:  zero or more fields of the form "tag[:value]"
(8) separator:  marks the end of the optional fields
(9) filesystem type:  name of filesystem of the form "type[.subtype]"
(10) mount source:  filesystem specific information or "none"
(11) super options:  per super block options

~ https://www.kernel.org/doc/Documentation/filesystems/proc.txt
*/

type mountpoint struct {
	root        string
	path        string
	fstype      string
	mountopts   []string
	mountsource string
}

func (m *mountpoint) isReadonly() bool {
	for _, opt := range m.mountopts {
		if opt == "ro" {
			return true
		}
	}
	return false
}

type simpleError string

func (s simpleError) Error() string {
	return string(s)
}

const ErrParseMountinfo = simpleError("csilvm: cannot parse /proc/self/mountinfo")

func listMounts() (mounts []mountpoint, err error) {
	buf, err := ioutil.ReadFile("/proc/self/mountinfo")
	if err != nil {
		return nil, err
	}
	for _, line := range strings.Split(string(buf), "\n") {
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		seperatorIdx := 0
		for ii := 6; ii < len(fields); ii++ {
			const seperator = "-"
			if fields[ii] == seperator {
				seperatorIdx = ii
			}
		}
		if seperatorIdx == 0 {
			return nil, ErrParseMountinfo
		}
		mount := mountpoint{
			root:        fields[3],
			path:        fields[4],
			fstype:      fields[seperatorIdx+1],
			mountopts:   strings.Split(fields[5], ","),
			mountsource: fields[seperatorIdx+2],
		}
		mounts = append(mounts, mount)
	}
	return mounts, nil
}

// getMountAt returns the first `mountpoint` that is mounted at the
// given path.
func getMountAt(path string) (*mountpoint, error) {
	mounts, err := getMountsAt(path)
	if err != nil {
		return nil, err
	}
	for _, mp := range mounts {
		return &mp, nil
	}
	return nil, nil
}

// getMountsAt returns all `mountpoint` that are mounted at the given
// path.
func getMountsAt(path string) ([]mountpoint, error) {
	mounts, err := listMounts()
	if err != nil {
		return nil, err
	}
	var mps []mountpoint
	for _, mp := range mounts {
		if mp.path == path {
			mps = append(mps, mp)
		}
	}
	return mps, nil
}
