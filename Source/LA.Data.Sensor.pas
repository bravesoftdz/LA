﻿unit LA.Data.Sensor;

interface

uses
  System.Classes;

type
  /// <summary>
  ///   Невизуальный компонент Датчик Мониторинга
  ///  содержит информацию о датчике Мониторинга:
  ///  - адрес в Мониторинге
  ///  - значение, момент времени и состояние
  /// </summary>
  [ObservableMember('Value')]
  [ObservableMember('Timestamp')]
  [ObservableMember('Status')]
  TDCSensor = class(TComponent) //, IDCObserver)
  private
    FID: Int64;
    FSID: string;
    FData: string;
    FValue: string;
    FTimestamp: TDateTime;
    FStatus: string;
    FEnabled: Boolean;
    FUpdateCounter: Integer;
    FIsDataChanged: Boolean;
    procedure SetSID(const Value: string);
    procedure SetValue(const Value: string);
    procedure SetStatus(const Value: string);
    procedure SetTimestamp(const Value: TDateTime);
    procedure SetEnabled(const Value: Boolean);
  private
    procedure DataChanged;
    procedure SetID(const Value: Int64);
  protected
    function CanObserve(const ID: Integer): Boolean; override;
    procedure ObserverAdded(const ID: Integer; const Observer: IObserver); override;
    procedure ObserverToggle(const AObserver: IObserver; const Value: Boolean);
  public
    function GetID: Int64;
    procedure SetData(const aData: string);

    procedure EncodeData(const aData: string);

    procedure BeginUpdate;
    procedure EndUpdate;
    procedure UpdateData(const aValue: string; aTimestamp: TDateTime; const aStatus: string);
  published
    property ID: Int64 read GetID write SetID;
    property SID: string read FSID write SetSID;

    property Value: string read FValue write SetValue;
    property Timestamp: TDateTime read FTimestamp write SetTimestamp;
    property Status: string read FStatus write SetStatus;
    property Data: string read FData write SetData;

    property Enabled: Boolean read FEnabled write SetEnabled;
  end;


implementation

uses
  System.SysUtils;

procedure TDCSensor.BeginUpdate;
begin
  Inc(FUpdateCounter);
end;

function TDCSensor.CanObserve(const ID: Integer): Boolean;
begin
  case ID of
    TObserverMapping.EditLinkID,
    TObserverMapping.ControlValueID:
      Result := True;
  else
    Result := False;
  end;
end;

procedure TDCSensor.DataChanged;
begin
  if (csLoading in ComponentState) or (csDestroying in ComponentState) then
    Exit;

  if FUpdateCounter = 0 then
  begin
    if FIsDataChanged then
      TLinkObservers.ControlChanged(Self);

    FIsDataChanged := False;
  end
  else
    FIsDataChanged := True;
end;

procedure TDCSensor.EncodeData(const aData: string);
begin

end;

procedure TDCSensor.EndUpdate;
begin
  Dec(FUpdateCounter);
  if FUpdateCounter = 0 then
    DataChanged;
end;

function TDCSensor.GetID: Int64;
begin
  Result := FID;
end;

procedure TDCSensor.ObserverAdded(const ID: Integer; const Observer: IObserver);
begin
  if ID = TObserverMapping.EditLinkID then
    Observer.OnObserverToggle := ObserverToggle;
end;

procedure TDCSensor.ObserverToggle(const AObserver: IObserver; const Value: Boolean);
var
  LEditLinkObserver: IEditLinkObserver;
begin
  if Value then
  begin
    if Supports(AObserver, IEditLinkObserver, LEditLinkObserver) then
      { disable the Item if the associated field does not support editing }
      Enabled := not LEditLinkObserver.IsReadOnly;
  end else
    Enabled := True;
end;

procedure TDCSensor.SetData(const aData: string);
begin
  if aData <> FData then
  begin
    EncodeData(aData);
    DataChanged;
  end;
end;

procedure TDCSensor.SetEnabled(const Value: Boolean);
begin
  FEnabled := Value;
end;

procedure TDCSensor.SetID(const Value: Int64);
begin
  FID := Value;
end;

procedure TDCSensor.SetSID(const Value: string);
begin
  FSID := Value;
end;

procedure TDCSensor.SetStatus(const Value: string);
begin
  if FStatus <> Value then
  begin
    FStatus := Value;
    DataChanged;
  end;
end;

procedure TDCSensor.SetTimestamp(const Value: TDateTime);
begin
  if FTimestamp <> Value then
  begin
    FTimestamp := Value;
    DataChanged;
  end;
end;

procedure TDCSensor.SetValue(const Value: string);
begin
  if FValue <> Value then
  begin
    FValue := Value;
    DataChanged;
  end;
end;

procedure TDCSensor.UpdateData(const aValue: string; aTimestamp: TDateTime; const aStatus: string);
begin
  if (FValue <> aValue) or (FTimestamp <> aTimestamp) or (FStatus <> aStatus) then
  begin
    FValue := aValue;
    FTimestamp := aTimestamp;
    FStatus := aStatus;
    DataChanged;
  end;
end;


end.
