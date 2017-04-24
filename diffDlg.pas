unit diffDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TdiffFrm = class(TForm)
    memoBox: TMemo;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  diffFrm: TdiffFrm;

implementation

{$R *.dfm}

end.
