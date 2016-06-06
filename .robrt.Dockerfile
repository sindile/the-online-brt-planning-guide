FROM ubuntu:16.04
ENV PS1="# "
RUN mkdir -p /var/git
RUN apt-get update
RUN apt-get install -y texlive
RUN apt-get install -y software-properties-common git texlive-xetex texlive-luatex latexmk
RUN apt-get install -y nodejs
RUN apt-get install -y time
RUN add-apt-repository -y ppa:haxe/snapshots && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib
RUN haxelib install utest
RUN haxelib install hxnodejs
RUN haxelib git hxparse https://github.com/jonasmalacofilho/hxparse && cd /usr/share/haxe/lib/hxparse/git && git checkout e0edc8d; cd -
RUN haxelib git assertion https://github.com/protocubo/assertion.hx && cd /usr/share/haxe/lib/assertion.hx/git && git checkout e464271; cd -

