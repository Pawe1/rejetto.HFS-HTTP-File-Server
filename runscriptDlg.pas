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
  main, Rejetto.Utils, Rejetto,
  Rejetto.Script, HFS.Template;

procedure TrunScriptFrm.runBtnClick(Sender: TObject);
var
  Template: TTemplate;
begin
  Template := TTemplate.Create;
  try
    try
      Template.fullText := loadFile(tempScriptFilename);
      resultBox.text := runScript(Template[''], NIL, Template);
      sizeLbl.Caption := getTill(':', sizeLbl.Caption) + ': ' +
        intToStr(length(resultBox.text));
    except
      on e: Exception do
        resultBox.text := e.message
    end;
  finally
    Template.Free;
  end;
end;

end.
