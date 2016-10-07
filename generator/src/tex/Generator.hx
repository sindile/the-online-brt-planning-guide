package tex;

import generator.tex.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import transform.NewDocument;
import transform.Context;
import util.sys.FsUtil;

import Assertion.*;

using Literals;
using StringTools;
using parser.TokenTools;

class Generator {
	static var FILE_BANNER = '
	% The Online BRT Planning Guide
	%
	% DO NOT EDIT THIS FILE MANUALLY!
	%
	% This file has been automatically generated from its sources
	% using the OBRT tool:
	%  tool version: ${Main.version.commit}
	%  haxe version: ${Main.version.haxe}
	%  runtime: ${Main.version.runtime}
	%  platform: ${Main.version.platform}
	'.doctrim();  // TODO runtime version, sources version

	var destDir:String;
	var preamble:StringBuf;
	var bufs:Map<String,StringBuf>;

	static var texEscapes = ~/([{}\$&#\^_%~])/g;  // FIXME complete with LaTeX/Math

	static inline var ASSET_SUBDIR = "assets";

	public function saveAsset(at:String, src:String):String
	{
		var ldir = Path.join([at, ASSET_SUBDIR]);
		var dir = Path.join([destDir, ldir]);
		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);

		var ext = Path.extension(src).toLowerCase();
		var data = File.getBytes(src);
		var hash = haxe.crypto.Sha1.make(data).toHex();

		// TODO question: is the extension even neccessary?
		var name = ext != "" ? hash + "." + ext : hash;
		var dst = Path.join([dir, name]);
		File.saveBytes(dst, data);

		var lpath = Path.join([ldir, name]);
		if (~/windows/i.match(Sys.systemName()))
			lpath = lpath.replace("\\", "/");
		assert(lpath.indexOf(" ") < 0, lpath, "spaces are toxic in TeX paths");
		assert(lpath.indexOf(".") == lpath.lastIndexOf("."), lpath, "unprotected dots are toxic in TeX paths");
		weakAssert(!Path.isAbsolute(lpath), "absolute paths might be toxic in TeX paths");
		weakAssert(~/[a-z\/-]+/.match(lpath), lpath, "weird chars are dangerous in TeX paths");
		return lpath;
	}

	public function gent(text:String)
	{
		text = text.split("\\").map(function (safe) {
			return texEscapes.replace(safe, "\\$1").replace("/", "\\slash{}");  // assumes texEscapes has 'g' flag
		}).join("\\textbackslash{}");
		// FIXME complete
		return text;
	}

	public function genp(pos:Position)
	{
		var lpos = pos.toLinePosition();
		if (Context.debug)
			return '% @ ${lpos.src}: lines ${lpos.lines.min + 1}-${lpos.lines.max}: code points ${lpos.codes.min + 1}-${lpos.codes.max}\n';  // TODO slow, be careful!
		return '% @ ${pos.src}: bytes ${pos.min + 1}-${pos.max}\n';
	}

	public function genh(h:HElem)
	{
		switch h.def {
		case Wordspace:
			return " ";
		case Superscript(h):
			return '\\textsuperscript{${genh(h)}}';
		case Subscript(h):
			return '\\textsubscript{${genh(h)}}';
		case Emphasis(h):
			return '\\emphasis{${genh(h)}}';
		case Highlight(h):
			return '\\highlight{${genh(h)}}';
		case Word(word):
			return gent(word);
		case InlineCode(code):
			return '\\code{${gent(code)}}';
		case Math(tex):
			return '$$$tex$$';
		case HElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genh(i));
			return buf.toString();
		case HEmpty:
			return "";
		}
	}

	public function genv(v:DElem, at:String, idc:IdCtx)
	{
		assert(!at.endsWith(".tex"), at, "should not but a directory");
		switch v.def {
		case DHtmlApply(_):
			return "";
		case DLaTeXPreamble(path):
			// TODO validate path (or has Transform done so?)
			preamble.add('% included from `$path`\n');
			preamble.add(genp(v.pos));
			preamble.add(File.getContent(path).trim());
			preamble.add("\n\n");
			return "";
		case DLaTeXExport(src, dest):
			assert(FileSystem.isDirectory(destDir));
			FsUtil.copy(src, Path.join([destDir, dest]));
			return "";
		case DVolume(no, name, children):
			idc.volume = v.id.sure();
			var id = idc.join(true, ":", volume);
			var path = Path.join([at, idc.volume+".tex"]);
			var dir = Path.join([at, idc.volume]);
			var buf = new StringBuf();
			bufs[path] = buf;
			buf.add("% This file is part of the\n");
			buf.add(FILE_BANNER);
			buf.add('\n\n\\volume{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, dir, idc)}');
			return '\\input{$path}\n\n';
		case DChapter(no, name, children):
			idc.chapter = v.id.sure();
			var id = idc.join(true, ":", volume, chapter);
			var path = Path.join([at, idc.chapter+".tex"]);
			var buf = new StringBuf();
			bufs[path] = buf;
			buf.add("% This file is part of the\n");
			buf.add(FILE_BANNER);
			buf.add('\n\n\\chapter{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}');
			return '\\input{$path}\n\n';
		case DSection(no, name, children):
			idc.section = v.id.sure();
			var id = idc.join(true, ":", volume, chapter, section);
			return '\\section{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}';
		case DSubSection(no, name, children):
			idc.subSection = v.id.sure();
			var id = idc.join(true, ":", volume, chapter, section, subSection);
			return '\\subsection{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}';
		case DSubSubSection(no, name, children):
			idc.subSubSection = v.id.sure();
			var id = idc.join(true, ":", volume, chapter, section, subSection, subSubSection);
			return '\\subsubsection{$no}{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at, idc)}';
		case DBox(no, name, children):
			idc.box = v.id.sure();
			var id = idc.join(true, ":", chapter, box);
			return '\\beginbox{$no}{${genh(name)}}\n\\label{$id}\n${genv(children, at, idc)}\\endbox\n${genp(v.pos)}\n';
		case DFigure(no, size, path, caption, cright):
			idc.figure = v.id.sure();
			var id = idc.join(true, ":", chapter, figure);
			path = saveAsset(at, path);
			// TODO handle size
			// TODO enable on XeLaTeX too
			// FIXME label
			return '
			\\ifxetex
				% disabled for now
			\\else
				{  % group required to avoid fignote settings escaping
					\\img{\\hsize}{$path}
					\\fignote{$no}{${genh(caption)}\\label{$id}}{${genh(cright)}}
				}
			\\fi'.doctrim() + "\n\n";  // FIXME use more neutral names
		case DTable(_):
			idc.table = v.id.sure();
			var id = idc.join(true, ":", chapter, table);
			return LargeTable.gen(v, id, this, at, idc);
		case DImgTable(no, size, caption, path):
			idc.table = v.id.sure();
			var id = idc.join(true, ":", chapter, table);
			path = saveAsset(at, path);
			// TODO handle size
			// TODO enable on XeLaTeX too
			// FIXME label
			return '
			\\ifxetex
				% disabled for now
			\\else
				{  % group required to avoid fignote settings escaping
					\\tabletitle{$no}{${genh(caption)}}\n\\label{$id}\n
					\\img{\\hsize}{$path}
				}
			\\fi'.doctrim() + "\n\n";  // FIXME use more neutral names
		case DList(numbered, li):
			var buf = new StringBuf();
			var env = numbered ? "enumerate" : "itemize";
			buf.add('\\begin{$env}\n');
			for (i in li)
				switch i.def {
				case DParagraph(h):
					buf.add('\\item ${genh(h)}${genp(i.pos)}');
				case _:
					buf.add('\\item {${genv(i, at, idc)}}\n');
				}
			buf.add('\\end{$env}\n');
			buf.add(genp(v.pos));
			buf.add("\n");
			return buf.toString();
		case DCodeBlock(code):
			show("code blocks in TeX improperly implemented");
			return '\\begincode\n${gent(code)}\n\\endcode\n${genp(v.pos)}\n';
		case DQuotation(text, by):
			return '\\quotation{${genh(text)}}{${genh(by)}}\n${genp(v.pos)}\n';
		case DParagraph(h):
			return '${genh(h)}\\par\n${genp(v.pos)}\n';
		case DElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genv(i, at, idc));
			return buf.toString();
		case DEmpty:
			return "";
		}
	}

	public function writeDocument(doc:NewDocument)
	{
		FileSystem.createDirectory(destDir);
		preamble = new StringBuf();
		preamble.add(FILE_BANNER);
		preamble.add("\n\n");

		var idc = new IdCtx();
		var contents = genv(doc, "./", idc);

		var root = new StringBuf();
		root.add(preamble.toString());
		root.add("\\begin{document}\n\n");
		root.add(contents);
		root.add("\\end{document}\n");
		bufs["book.tex"] = root;

		for (p in bufs.keys()) {
			var path = Path.join([destDir, p]);
			FileSystem.createDirectory(Path.directory(path));
			File.saveContent(path, bufs[p].toString());
		}
	}

	public function new(destDir)
	{
		// TODO validate destDir
		this.destDir = destDir;
		bufs = new Map();
	}
}

