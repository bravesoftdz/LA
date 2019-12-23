unit LA.DC.SystemUtils;

interface
  uses
    System.SysUtils
{$IFDEF WIN32}
    , Winapi.Windows
{$ELSE}
{$ENDIF}
    ;



type
  TDCSystemUtils = class
  public
    class function GetLocalUserName: string;
    class function GetComputerName: string;
  end;

implementation

{ TDCSystemUtils }

class function TDCSystemUtils.GetComputerName: string;
{$IFDEF WIN32}
var
  Count: UInt32;
begin
  Count := 256 + 1; // UNLEN + 1
  SetLength(Result, Count);
  if GetUserName(PChar(Result), Count) then
    SetLength(Result, StrLen(PChar(Result)))
  else
    Result := '';
{$ELSE}
begin
  Result := '';
{$ENDIF}
end;

class function TDCSystemUtils.GetLocalUserName: string;
{$IFDEF WIN32}
var
  Count: UInt32;
begin
  Count := 256 + 1; // UNLEN + 1
  SetLength(Result, Count);
  if GetUserName(PChar(Result), Count) then
    SetLength(Result, StrLen(PChar(Result)))
  else
    Result := '';
{$ELSE}
begin
  Result := '';
{$ENDIF}
end;

end.
