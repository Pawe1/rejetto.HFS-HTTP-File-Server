unit runscriptDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TrunScriptFrm = class(TForm)
    resultBox: TMemo;
    Panel1: TPanel;
    runBtn: TButton;
    autorunChk: TCheckBox;
    sizeLbl: TLabel;
    procedure runBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  runScriptFrm: TrunScriptFrm;

implementation

{$R *.dfm}

uses
  main, utilLib, classesLib, scriptLib;

procedure TrunScriptFrm.runBtnClick(Sender: TObject);
var
  tpl: Ttpl;
begin
  tpl := Ttpl.create;
  try
    try
      tpl.fullText := loadFile(tempScriptFilename);
      resultBox.text := runScript(tpl[''], NIL, tpl);
      sizeLbl.Caption := getTill(':', sizeLbl.Caption) + ': ' +
        intToStr(length(resultBox.text));
    except
      on e: Exception do
        resultBox.text := e.message
    end;
  finally
    tpl.free
  end;
end;

end.
