unit purgeDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TpurgeFrm = class(TForm)
    rmFilesChk: TCheckBox;
    Label1: TLabel;
    rmRealFoldersChk: TCheckBox;
    rmEmptyFoldersChk: TCheckBox;
    Button1: TButton;
    Button2: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  purgeFrm: TpurgeFrm;

implementation

{$R *.dfm}

end.
