unit HFS.Accounts;

interface

uses
  System.Types;

type
	TAccount = record // user/pass profile
    user: string;
    pwd: string;
    redir: string;
    notes: string;
    wasUser: string; // used in user renaming panel
    enabled: Boolean;
    noLimits: Boolean;
    group: Boolean;
    link: TStringDynArray;
  end;
  PAccount = ^TAccount;

  TAccounts = array of TAccount;

implementation

end.
