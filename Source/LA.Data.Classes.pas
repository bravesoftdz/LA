﻿unit LA.Data.Classes;

{
  *****************************************************************************
  - TDataUpdater - компонент, который содержит
    - Список подписок
    - подключение к серверу Мониторинга
    - поток, который периодически выполняет запросы к серверу и уведомляет наблюдаетелей об изменениях
  - Наблюдатели должны подписываться на уведомления, при этом создается объект Cвязка (TDCLink)

  *****************************************************************************
}

interface

uses
  System.Classes, System.SysUtils,
  System.Generics.Collections,
//  Spring.DesignPatterns,
  LA.Threads,
  LA.DC.CustomConnector;

type
  // наблюдатель (датчик, трекер, маркер...)
  IDCObserver = interface(IInvokable)
    // получить идентификатор, например адрес датчика или трекера
    function GetID: string;
    // установить новые данные
    procedure SetData(const aData: string);
  end;

  // объект, за которым можно наблюдать
  // к нему можно подключаться/отключаться и он может сообщать, что что-то изменилось
  // aLink - это специальный объект, который создается в момент подключения и содержит в себе ссылку на наблюдателя
  IDCObservable<T> = interface(IInvokable)
    procedure Attach(const aLink: T);
    procedure Detach(const aLink: T);
    procedure Notify;
  end;

  // содержит параметры датчика Мониторинга, его значение и состояние
  [ObservableMember('Value')]
  [ObservableMember('Timestamp')]
  [ObservableMember('Status')]
  TDCSensor = class(TComponent, IDCObserver)
  private
    FData: string;
    FSID: string;
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
  protected
    function CanObserve(const ID: Integer): Boolean; override;
    procedure ObserverAdded(const ID: Integer; const Observer: IObserver); override;
    procedure ObserverToggle(const AObserver: IObserver; const Value: Boolean);
  public
    // реализация IDCObserver
    function GetID: string;
    procedure SetData(const aData: string);

    procedure EncodeData(const aData: string);

    procedure BeginUpdate;
    procedure EndUpdate;
    procedure UpdateData(const aValue: string; aTimestamp: TDateTime; const aStatus: string);
  published
    property SID: string read FSID write SetSID;

    property Value: string read FValue write SetValue;
    property Timestamp: TDateTime read FTimestamp write SetTimestamp;
    property Status: string read FStatus write SetStatus;
    property Data: string read FData write SetData;

    property Enabled: Boolean read FEnabled write SetEnabled;
  end;

  // связка с Наблюдателем
  TDCLink = class
  private
    FData: string;
    FObserver: IDCObserver;
  public
    constructor Create(aObserver: IDCObserver);
    procedure Notify;

    property Observer: IDCObserver read FObserver;
    property Data: string read FData write FData;
  end;

  // список связок с Наблюдателями
  TDCLinkList = class(TObjectList<TDCLink>)
  end;


  // объект, который получает данные из Мониторинга и уведомляет подписчиков
  TDataUpdater = class(TComponent, IDCObservable<TDCLink>)
  private
    const
      MinInterval = 100;
      DefInterval = 1000;
    type
      // поток для получения данных с сервера Мониторинга
      TDataUpdateThread = class(TDCIntervalThread)
      private
        FUpdater: TDataUpdater;
      protected
        procedure ProcessTimer; override;
      public
        constructor Create(CreateSuspended: Boolean; aUpdater: TDataUpdater; aInterval: Int64); overload;
      end;
  private
    FLock: TMREWSync;
    FLinks: TDCLinkList;
    FLinksChanged: Boolean;
    FThread: TDataUpdateThread;
    FInterval: Int64;
    FConnector: TDCCustomConnector;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
    procedure Start;
    procedure Stop;
    procedure SetInterval(const Value: Int64);
    procedure DoThreadTerminated(aSender: TObject);
    procedure SetConnector(const Value: TDCCustomConnector);
  protected
    procedure DoNotify(const aLink: TDCLink); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // подключение, отключение, уведомление наблюдателей
    procedure Attach(const aLink: TDCLink);
    procedure Detach(const aLink: TDCLink);
    procedure Notify;

    // формирование строки запрашиваемых адресов
    function GetRequestedAddresses: string;
    // разбор ответа сервера
    procedure ProcessServerResponce(const aResponce: string);

    // список линков, в которых есть ссылки на наблюдателей
    property Links: TDCLinkList read FLinks;
  published
    // подключение к серверу Мониторинга
    property Connector: TDCCustomConnector read FConnector write SetConnector;
    // включать будем по необходимости
    property Active: Boolean read GetActive write SetActive stored False;
    // период опроса сервера, мс
    property Interval: Int64 read FInterval write SetInterval;
  end;

implementation

uses
  System.Math;

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

function TDCSensor.GetID: string;
begin
  Result := SID;
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


procedure TDataUpdater.Attach(const aLink: TDCLink);
begin
  FLock.BeginWrite;
  try
    FLinks.Add(aLink);
    FLinksChanged := True;
  finally
    FLock.EndWrite;
  end;
end;

constructor TDataUpdater.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInterval := DefInterval;
  FLock := TMREWSync.Create;
  FLinks := TDCLinkList.Create;
end;

destructor TDataUpdater.Destroy;
begin
  Active := False;
  FLinks.Free;
  FLock.Free;
  inherited;
end;

procedure TDataUpdater.Detach(const aLink: TDCLink);
begin
  FLock.BeginWrite;
  try
    FLinks.Remove(aLink);
    FLinksChanged := True;
  finally
    FLock.EndWrite;
  end;
end;

procedure TDataUpdater.DoNotify(const aLink: TDCLink);
begin
  aLink.Observer.SetData(aLink.Data);
end;

procedure TDataUpdater.DoThreadTerminated(aSender: TObject);
begin
  FreeAndNil(FThread);
end;

function TDataUpdater.GetActive: Boolean;
begin
  Result := Assigned(FThread);
end;

function TDataUpdater.GetRequestedAddresses: string;
var
  aLink: TDCLink;
begin
  Result := '';
  FLock.BeginRead;
  try
    for aLink in FLinks do
      Result := Result + aLink.Observer.GetID + ';';
  finally
    FLock.EndRead;
  end;
end;

procedure TDataUpdater.Notify;
var
  aLink: TDCLink;
begin
  FLock.BeginRead;
  try
    for aLink in FLinks do
      DoNotify(aLink);
  finally
    FLock.EndRead;
  end;
end;

procedure TDataUpdater.ProcessServerResponce(const aResponce: string);
const
  cDataDelimiter = #13;
var
  p1, p2: Integer;
  i, aLinkIndex, aLinkMaxIndex: Integer;
begin
  if FLinksChanged then
    Exit;

  aLinkMaxIndex := FLinks.Count - 1;
  if aLinkMaxIndex < 0 then
    Exit;

  p1 := 1;
  aLinkIndex := 0;

  FLock.BeginRead;
  try
    for i := 1 to Length(aResponce) do
    begin
      if aResponce[i] = cDataDelimiter then
      begin
        p2 := i;
        FLinks[aLinkIndex].Data := Copy(aResponce, p1, p2 - p1);
        p1 := p2 + 1;
        if aLinkIndex = aLinkMaxIndex then
          Exit;
      end;
    end;

  finally
    FLock.EndRead;
  end;
end;

procedure TDataUpdater.SetActive(const Value: boolean);
begin
  if Value then
    Start
  else
    Stop;
end;

procedure TDataUpdater.SetConnector(const Value: TDCCustomConnector);
begin
  // нельзя изменить коннктор, во время работы потока
  if Active then
    Exit;

  FConnector := Value;
end;

procedure TDataUpdater.SetInterval(const Value: Int64);
begin
  if FInterval <> Value then
  begin
    FInterval := Max(Value, MinInterval);
    if Active then
      FThread.Interval := FInterval;
  end;
end;

procedure TDataUpdater.Start;
begin
  if Active then
    Exit;

  FThread := TDataUpdateThread.Create(True, Self, Interval);
  FThread.OnTerminate := DoThreadTerminated;
  FThread.Start;
end;

procedure TDataUpdater.Stop;
begin
  if Active then
    Exit;

  FThread.Terminate;
  FThread.WaitFor;
end;

constructor TDCLink.Create(aObserver: IDCObserver);
begin
  FObserver := aObserver;
end;

procedure TDCLink.Notify;
begin
  Observer.SetData(Data);
end;

{ TDataUpdater.TDataUpdateThread }

constructor TDataUpdater.TDataUpdateThread.Create(CreateSuspended: Boolean; aUpdater: TDataUpdater; aInterval: Int64);
begin
  inherited Create(CreateSuspended, aInterval);
  FUpdater := aUpdater;
end;

procedure TDataUpdater.TDataUpdateThread.ProcessTimer;
begin
  // запрашиваем данные с сервера
  // обновляем линки
  // уведомляем наблюдателей
end;

end.
