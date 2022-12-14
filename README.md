# remote-dev
Simple program for making it easy to perform remote dev work, such as developing on a Raspberry Pi. The purpose is to automatically sync the project repository as you work.

## Background
This script was inspired from a similar purposed script by glaszig (https://gist.github.com/glaszig/673691a6ba7bdc8e3d054d826a179976#file-fswatch-scp-sh). I added the an initial sync at launch using ssh to transfer an in-memory tarball of the local project, as well as logging.

## Installation
It is recommended to clone this repository to your local computer then symlink the remote-dev.sh file to a directory available in your system path. I like to create a .bin folder in my home directory then add to my PATH variable in my .bashrc file.

Example:
~~~
cd ~/Repositories
git clone git@github.com:twistedx-opensource/remote-dev.git
mkdir -p ~/.bin
ln ${HOME}/Repositories/remote-dev/remote-dev.sh ${HOME}/.bin/remote-dev
echo "PATH=~/.bin:$PATH" >> ~/.bashrc
source ~/.bashrc
~~~

## Instructions

Running the program will walk you through initial configuration.

~~~
Usage: remote-dev <watch-dir> <target> [OPTIONS...]
  watch-dir:            path to a local directory to watch
  target:               an scp target specification, e.g.
                        user@host.domain:/var/tmp
  --host-ip ip-address: optional ip address for unsupported
                        operating systems or VPNs
  --check-host-key:     Enforce host key checking
  -y, --yes:            Assume yes for all prompts
~~~

## License
Copyright 2022 Jason Scheunemann

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
