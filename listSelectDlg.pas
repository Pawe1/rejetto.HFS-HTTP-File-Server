unit listSelectDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.CheckLst;

type
  TlistSelectFrm = class(TForm)
    listBox: TCheckListBox;
    Panel1: TPanel;
    okBtn: TButton;
    cancelBtn: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

function listSelect(title:string; var options:TstringList):boolean;

implementation

{$R *.dfm}

uses
  Rejetto.Utils;

function listSelect(title: string; var options: TstringList): boolean;
var
  dlg: TlistSelectFrm;
  i: integer;
begin
  result := FALSE;
  dlg := TlistSelectFrm.Create(NIL);
  with dlg do
    try
      caption := title;
      listBox.items.assign(options);
      for i := 0 to options.count - 1 do
        if options.objects[i] <> NIL then
          listBox.Checked[i] := TRUE;
      clientHeight := clientHeight - listBox.clientHeight + listBox.ItemHeight *
        minmax(5, 15, listBox.count);
      if showModal() = mrCancel then
        exit;
      for i := 0 to listBox.count - 1 do
        options.objects[i] := if_(listBox.Checked[i], PTR1, NIL);
      result := TRUE;
    finally
      dlg.free
    end;
end;

end.
