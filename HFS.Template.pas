unit HFS.Template;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes, System.Types, System.IniFiles,
  Rejetto.HS;

type
  TTemplateSection = record
    name, txt: string;
    nolog, nourl: boolean;
  end;
  PTemplateSection = ^TTemplateSection;

  TTemplate = class
  strict private
    type
      TLast = record
        section: string;
        idx: integer;
      end;
  protected
    src: string;
    lastExt, // cache for getTxtByExt()
    last: TLast; // cache for getIdx()
    fileExts: TStringDynArray;
    strTable: THashedStringList;
    fUTF8: boolean;
    fOver: TTemplate;
    function getIdx(section: string): integer;
    function getTxt(section: string): string;
    function newSection(section: string): PTemplateSection;
    procedure fromString(txt: string);
    procedure setOver(v: TTemplate);
    procedure updateUTF8();
  public
    onChange: TNotifyEvent;
    sections: array of TTemplateSection;
    constructor create(txt: string = ''; over: TTemplate = NIL);
    destructor Destroy; override;
    property txt[section: string]: string read getTxt; default;
    property fullText: string read src write fromString;
    property utf8: boolean read fUTF8;
    property over: TTemplate read fOver write setOver;
    function sectionExist(section: string): boolean;
    function getTxtByExt(fileExt: string): string;
    function getSection(section: string): PTemplateSection;
    function getSections(): TStringDynArray;
    procedure appendString(txt: string);
    function getStrByID(id: string): string;
    function me(): TTemplate;
  end;

  TCachedTplObj = class
    ts: Tdatetime;
    Tpl: TTemplate;
  end;

  TCachedTemplates = class(THashedStringList)
  public
    function getTplFor(fn: string): TTemplate;
    destructor Destroy; override;
  end;

implementation

uses
  System.StrUtils, System.SysUtils, System.Math,
  windows, dateUtils,
  Rejetto.Utils, main;

/// ///////// TcachedTpls

destructor TCachedTemplates.Destroy;
var
  i: integer;
begin
  for i := 0 to count - 1 do
    objects[i].free;
end;

function TCachedTemplates.getTplFor(fn: string): TTemplate;
var
  i: integer;
  o: TCachedTplObj;
  s: string;
begin
  fn := trim(lowercase(fn));
  i := indexOf(fn);
  if i >= 0 then
    o := objects[i] as TCachedTplObj
  else
  begin
    o := TCachedTplObj.create();
    if addObject(fn, o) > 100 then
      delete(0);
  end;
  result := o.tpl;
  if getMtime(fn) = o.ts then
    exit;
  o.ts := getMtime(fn);
  s := loadFile(fn);
  if o.tpl = NIL then
  begin
    result := TTemplate.create();
    o.tpl := result;
  end;
  o.tpl.fromString(s);
end; // getTplFor

/// ///////// Ttpl

constructor TTemplate.create(txt: string = ''; over: TTemplate = NIL);
begin
  fullText := txt;
  self.over := over;
end;

destructor TTemplate.Destroy;
begin
  freeAndNIL(strTable);
  inherited;
end; // destroy

function TTemplate.getStrByID(id: string): string;
begin
  if strTable = NIL then
  begin
    strTable := ThashedStringList.create;
    strTable.text := txt['special:strings'];
  end;
  result := strTable.values[id];
  if (result = '') and assigned(over) then
    result := over.getStrByID(id)
end; // getStrByID

function TTemplate.getIdx(section: string): integer;
begin
  if section <> last.section then
  begin
    last.section := section;
    for result := 0 to length(sections) - 1 do
      if sameText(sections[result].name, section) then
      begin
        last.idx := result;
        exit;
      end;
    last.idx := -1;
  end;
  result := last.idx
end; // getIdx

function TTemplate.newSection(section: string): PTemplateSection;
var
  i: integer;
begin
  // add
  i := length(sections);
  setLength(sections, i + 1);
  result := @sections[i];
  result.name := section;
  // getIdx just filled 'last' with not-found, so we must update
  last.section := section;
  last.idx := i;
  // manage file.EXT sections
  if not ansiStartsText('file.', section) then
    exit;
  i := length(fileExts);
  setLength(fileExts, i + 2);
  delete(section, 1, 4);
  fileExts[i] := section;
  fileExts[i + 1] := str_(last.idx);
  lastExt.section := section;
  lastExt.idx := last.idx;
end; // newSection

function TTemplate.sectionExist(section: string): boolean;
begin
  result := getIdx(section) >= 0;
  if not result and assigned(over) then
    result := over.sectionExist(section);
end;

function TTemplate.getSection(section: string): PTemplateSection;
var
  i: integer;
begin
  result := NIL;
  i := getIdx(section);
  if i >= 0 then
    result := @sections[i];
  if assigned(over) and ((result = NIL) or (trim(result.txt) = '')) then
    result := over.getSection(section);
end; // getSection

function TTemplate.getTxt(section: string): string;
var
  i: integer;
begin
  i := getIdx(section);
  if i >= 0 then
    result := sections[i].txt
  else if assigned(over) then
    result := over[section]
  else
    result := ''
end; // getTxt

function TTemplate.getTxtByExt(fileExt: string): string;
var
  i: integer;
begin
  result := '';
  if (lastExt.section > '') and (fileExt = lastExt.section) then
  begin
    if lastExt.idx >= 0 then
      result := sections[lastExt.idx].txt;
    exit;
  end;
  i := idxOf(fileExt, fileExts);
  if (i < 0) and assigned(over) then
  begin
    result := over.getTxtByExt(fileExt);
    if result > '' then
      exit;
  end;
  lastExt.section := fileExt;
  lastExt.idx := i;
  if i < 0 then
    exit;
  i := int_(fileExts[i + 1]);
  lastExt.idx := i;
  result := sections[i].txt;
end; // getTxtByExt

procedure TTemplate.fromString(txt: string);
begin
  src := '';
  sections := NIL;
  fileExts := NIL;
  last.section := #255'null';
  // '' is a valid (and often used) section name. This is a better null value.
  freeAndNIL(strTable); // mod by mars

  appendString(txt);
end; // fromString

procedure TTemplate.appendString(txt: string);
var
  ptxt, bos: Pchar;
  cur_section, next_section: string;

  function pred(p: Pchar): Pchar; inline;
  begin
    result := p;
    if p <> NIL then
      dec(result);
  end;

  function succ(p: Pchar): Pchar; inline;
  begin
    result := p;
    if p <> NIL then
      inc(result);
  end;

  procedure findNextSection();
  begin
    // find start
    bos := ptxt;
    repeat
      if bos^ <> '[' then
        bos := ansiStrPos(bos, #10'[');
      if bos = NIL then
        exit;
      if bos^ = #10 then
        inc(bos);
      if getSectionAt(bos, next_section) then
        exit;
      inc(bos);
    until FALSE;
  end; // findNextSection

  procedure saveInSection();
  var
    ss: TstringDynArray;
    s: string;
    i, si: integer;
    base: TTemplateSection;
    till: Pchar;
    append: boolean;
    sect, from: PTemplateSection;
  begin
    till := pred(bos);
    if till = NIL then
      till := pred(strEnd(ptxt));
    if till^ = #10 then
      dec(till);
    if till^ = #13 then
      dec(till);

    base.txt := getStr(ptxt, till);
    // there may be flags after |
    s := cur_section;
    cur_section := chop('|', s);
    base.nolog := ansiPos('no log', s) > 0;
    base.nourl := ansiPos('private', s) > 0;
    // there may be several section names separated by =
    ss := split('=', cur_section);
    // handle the main section specific case
    if ss = NIL then
      addString('', ss);
    // assign to every name the same txt
    for i := 0 to length(ss) - 1 do
    begin
      s := trim(ss[i]);
      append := ansiStartsStr('+', s);
      if append then
        delete(s, 1, 1);
      si := getIdx(s);
      from := NIL;
      if si < 0 then // not found
      begin
        if append then
          from := getSection(s);
        sect := newSection(s);
      end
      else
      begin
        sect := @sections[si];
        if append then
          from := sect;
      end;
      if from <> NIL then
      begin // inherit from it
        sect.txt := from.txt + base.txt;
        sect.nolog := from.nolog or base.nolog;
        sect.nourl := from.nourl or base.nourl;
        continue;
      end;
      sect^ := base;
      sect.name := s; // restore this lost attribute
    end;
  end; // saveInSection

const
  BOM = #$EF#$BB#$BF;
var
  first: boolean;
begin
  // this is used by some unicode files. at the moment we just ignore it.
  if ansiStartsStr(BOM, txt) then
    delete(txt, 1, length(BOM));

  if txt = '' then
    exit;
  src := src + txt;
  cur_section := '';
  ptxt := @txt[1];
  first := TRUE;
  repeat
    findNextSection();
    if not first or (trim(getStr(ptxt, pred(bos))) > '') then
      saveInSection();
    if bos = NIL then
      break;
    cur_section := next_section;
    inc(bos, length(cur_section)); // get faster to the end of line
    ptxt := succ(ansiStrPos(bos, #10));
    // get to the end of line (and then beyond)
    first := FALSE;
  until ptxt = NIL;
  updateUTF8();
  if assigned(onChange) then
    onChange(self);
end; // appendString

procedure TTemplate.setOver(v: TTemplate);
begin
  fOver := v;
  updateUTF8();
end; // setOver

procedure TTemplate.updateUTF8();
begin
  fUTF8 := assigned(over) and over.utf8 or utf8test(fullText)
end;

function TTemplate.getSections(): TstringDynArray;
var
  i: integer;
begin
  i := length(sections);
  setLength(result, i);
  for i := 0 to i - 1 do
    result[i] := sections[i].name;
end;

function TTemplate.me(): TTemplate;
begin
  result := self
end;

end.
