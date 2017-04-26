unit HFS.Template;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes, System.Types, System.SysUtils,
  System.IniFiles,
  Rejetto.HTTPServer;

type
  TTemplateSection = record
    name: string;
    txt: string;
    nolog: Boolean;
    nourl: Boolean;
  end;
  PTemplateSection = ^TTemplateSection;

  TTemplate = class
  strict private
    type
      TLast = record
        section: string;
        idx: integer;
      end;
  strict private
    FSrc: string;
    FLastExt, // cache for getTxtByExt()
    FLast: TLast; // cache for getIdx()
    FFileExts: TStringDynArray;
    FStrTable: THashedStringList;
    fUTF8: boolean;
    fOver: TTemplate;
    function getIdx(section: string): integer;
    function getTxt(section: string): string;
    function newSection(section: string): PTemplateSection;
    procedure setOver(v: TTemplate);
    procedure updateUTF8();
  protected
    procedure fromString(txt: string);
  public
    onChange: TNotifyEvent;
    sections: array of TTemplateSection;
    constructor create(txt: string = ''; over: TTemplate = NIL);
    destructor Destroy; override;
    function sectionExist(section: string): boolean;
    function getTxtByExt(fileExt: string): string;
    function getSection(section: string): PTemplateSection;
    function getSections(): TStringDynArray;
    procedure appendString(txt: string);
    function getStrByID(id: string): string;
    function me(): TTemplate;
    property txt[section: string]: string read getTxt; default;
    property fullText: string read FSrc write fromString;
    property utf8: boolean read fUTF8;
    property over: TTemplate read fOver write setOver;
  end;

  TCachedTplObj = class
    ts: Tdatetime;
    Tpl: TTemplate;
  end;

  TCachedTemplates = class(THashedStringList)
  public
    destructor Destroy; override;
    function getTplFor(fn: string): TTemplate;
  end;

  ETemplateError = class(Exception)
    pos, row, col: integer;
    code: string;
    constructor Create(const msg, code: string; row, col: integer);
  end;

implementation

uses
  System.StrUtils, System.Math,
  windows, dateUtils,
  Rejetto.Utils, main, Rejetto.Utils.Conversion, Rejetto.Utils.Text;

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
  freeAndNIL(FStrTable);
  inherited;
end; // destroy

function TTemplate.getStrByID(id: string): string;
begin
  if FStrTable = NIL then
  begin
    FStrTable := ThashedStringList.create;
    FStrTable.text := txt['special:strings'];
  end;
  result := FStrTable.values[id];
  if (result = '') and assigned(over) then
    result := over.getStrByID(id)
end; // getStrByID

function TTemplate.getIdx(section: string): integer;
begin
  if section <> FLast.section then
  begin
    FLast.section := section;
    for result := 0 to length(sections) - 1 do
      if sameText(sections[result].name, section) then
      begin
        FLast.idx := result;
        exit;
      end;
    FLast.idx := -1;
  end;
  result := FLast.idx
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
  FLast.section := section;
  FLast.idx := i;
  // manage file.EXT sections
  if not ansiStartsText('file.', section) then
    exit;
  i := length(FFileExts);
  setLength(FFileExts, i + 2);
  delete(section, 1, 4);
  FFileExts[i] := section;
  FFileExts[i + 1] := str_(FLast.idx);
  FLastExt.section := section;
  FLastExt.idx := FLast.idx;
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
  if (FLastExt.section > '') and (fileExt = FLastExt.section) then
  begin
    if FLastExt.idx >= 0 then
      result := sections[FLastExt.idx].txt;
    exit;
  end;
  i := idxOf(fileExt, FFileExts);
  if (i < 0) and assigned(over) then
  begin
    result := over.getTxtByExt(fileExt);
    if result > '' then
      exit;
  end;
  FLastExt.section := fileExt;
  FLastExt.idx := i;
  if i < 0 then
    exit;
  i := int_(FFileExts[i + 1]);
  FLastExt.idx := i;
  result := sections[i].txt;
end; // getTxtByExt

procedure TTemplate.fromString(txt: string);
begin
  FSrc := '';
  sections := NIL;
  FFileExts := NIL;
  FLast.section := #255'null';
  // '' is a valid (and often used) section name. This is a better null value.
  freeAndNIL(FStrTable); // mod by mars

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
  FSrc := FSrc + txt;
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

constructor ETemplateError.Create(const msg, code: string; row, col: integer);
begin
  inherited Create(msg);
  self.row := row;
  self.col := col;
  self.code := code;
end;

end.
