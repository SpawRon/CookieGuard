# ============================================================
#  CookieGuard - Ui.MainXaml.ps1
#  Разметка главного окна.
#
#  Раскладка повторяет «Параметры» Windows 11: слева столбец
#  разделов, справа страница из карточек. Выбрано не ради
#  похожести — человек, который открыл программу после взлома,
#  не должен ещё и разбираться, где у неё что. Он уже знает.
#
#  Три полосы вместо прежних двух:
#    слева  — разделы,
#    в центре — страница,
#    справа — разбор выбранной строки.
#  Раньше разбор жил узкой полосой внизу: в неё не помещалось
#  ни подробностей, ни кнопок, и половина действий терялась.
#  Справа места столько же, сколько у текста, и ничего не надо
#  перекладывать.
#
#  Имена всех элементов сохранены прежними: к ним привязаны
#  обработчики в CookieGuard.ps1.
# ============================================================

$script:CgMainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="CookieGuard" Height="880" Width="1340" MinHeight="660" MinWidth="1080"
        WindowStyle="None" Background="#101217" WindowStartupLocation="CenterScreen">
  <shell:WindowChrome.WindowChrome>
    <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0"
                        CornerRadius="0" UseAeroCaptionButtons="False"/>
  </shell:WindowChrome.WindowChrome>

  <Window.Resources>
<!--THEME-->

    <!-- заголовок группы в списке разделов -->
    <Style x:Key="NavHeader" TargetType="ListBoxItem">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsHitTestVisible" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <TextBlock Text="{TemplateBinding Content}" Foreground="#6B7482" FontSize="10.5" FontWeight="SemiBold"
                       Margin="15,16,0,6"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- строка настройки: значок, название, пояснение, управление -->
    <Style x:Key="SettingIcon" TargetType="Border">
      <Setter Property="Width" Value="32"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="CornerRadius" Value="16"/>
      <Setter Property="Background" Value="#1F2630"/>
      <Setter Property="Margin" Value="0,0,14,0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="SettingIconGlyph" TargetType="TextBlock" BasedOn="{StaticResource Glyph}">
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="Foreground" Value="#9FB3C8"/>
    </Style>
    <Style x:Key="SettingName" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize" Value="13.5"/>
    </Style>

    <Style x:Key="PageHead" TargetType="StackPanel">
      <Setter Property="Margin" Value="0,0,0,18"/>
    </Style>
  </Window.Resources>

  <Border BorderBrush="#2A303A" BorderThickness="1">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="44"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- ===================== ЗАГОЛОВОК ОКНА ===================== -->
    <Border Grid.Row="0" Background="#15181E" BorderBrush="#232832" BorderThickness="0,0,0,1">
      <Grid x:Name="TitleBar" Background="Transparent">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="14,0,0,0">
          <Border Width="24" Height="24" CornerRadius="7" Background="#1E3A5C">
            <TextBlock Text="&#xE72E;" Style="{StaticResource Glyph}" FontSize="13" Foreground="#3B9EFF"/>
          </Border>
          <TextBlock Text="CookieGuard" FontWeight="SemiBold" FontSize="13.5" Margin="11,0,0,0" VerticalAlignment="Center"/>
          <Border Width="1" Background="#2A303A" Margin="14,12,14,12"/>
          <TextBlock Text="наблюдение за доступом к cookie и паролям" Style="{StaticResource Sub}"
                     FontSize="11.5" VerticalAlignment="Center"/>
        </StackPanel>

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock x:Name="ChipAdmin" Text="" Style="{StaticResource Sub}" FontSize="11.5" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <Border Background="#1B1F26" CornerRadius="11" Padding="10,3" Margin="0,0,8,0" BorderBrush="#262B34" BorderThickness="1">
            <TextBlock x:Name="ChipAudit" Text="" FontSize="11.5" VerticalAlignment="Center"/>
          </Border>
          <Border Background="#1B1F26" CornerRadius="11" Padding="10,3" Margin="0,0,14,0" BorderBrush="#262B34" BorderThickness="1">
            <TextBlock x:Name="ChipMon" Text="" FontSize="11.5" VerticalAlignment="Center"/>
          </Border>
          <Button x:Name="BtnMinW"   Content="&#xE921;" Style="{StaticResource CaptionBtn}"/>
          <Button x:Name="BtnMaxW"   Content="&#xE922;" Style="{StaticResource CaptionBtn}"/>
          <Button x:Name="BtnCloseW" Content="&#xE8BB;" Style="{StaticResource CaptionClose}"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- ===================== ТЕЛО ОКНА ===================== -->
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="252"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <!-- ========== столбец разделов ========== -->
      <Border Grid.Column="0" Background="#15181E" BorderBrush="#232832" BorderThickness="0,0,1,0">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top" Margin="12,14,12,6">
            <Button x:Name="BtnScan" Content="Проверить систему" Style="{StaticResource Primary}" Height="38" Margin="0,0,0,8"/>
            <Button x:Name="BtnScanFiles" Content="Проверить файл или папку" Height="36" Margin="0,0,0,0"/>
            <Button x:Name="BtnMon" Content="Запустить монитор" Height="36" Margin="0,8,0,0"/>
          </StackPanel>
          <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="0,6,0,10">
            <ListBox x:Name="Nav" Style="{StaticResource NavList}" ItemContainerStyle="{StaticResource NavItem}">
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE80F;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Обзор" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE72E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Защита" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>

              <ListBoxItem Content="НАБЛЮДЕНИЕ" Style="{StaticResource NavHeader}"/>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE768;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Монитор" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE7BA;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Находки" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE9D9;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Процессы" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE71D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Расширения" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE7E8;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Автозапуск" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE81C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Запуски" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>

              <ListBoxItem Content="РАЗБОР" Style="{StaticResource NavHeader}"/>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE74D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Карантин" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE8FB;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Доверенные" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="&#xE8A5;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Width="26" VerticalAlignment="Center"/>
                  <TextBlock Text="Журнал" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
            </ListBox>
          </ScrollViewer>
        </DockPanel>
      </Border>

      <!-- ========== страницы ========== -->
      <TabControl x:Name="Tabs" Grid.Column="1" Background="#101217" BorderThickness="0">
        <TabControl.ItemContainerStyle>
          <Style TargetType="TabItem"><Setter Property="Visibility" Value="Collapsed"/></Style>
        </TabControl.ItemContainerStyle>
        <TabControl.Template>
          <ControlTemplate TargetType="TabControl">
            <ContentPresenter ContentSource="SelectedContent"/>
          </ControlTemplate>
        </TabControl.Template>

        <!-- ========== ОБЗОР ========== -->
        <TabItem Header="Обзор">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="30,26,30,24">
              <StackPanel Style="{StaticResource PageHead}">
                <TextBlock Text="Обзор" Style="{StaticResource H1}"/>
                <TextBlock Text="Состояние наблюдения и итог последней проверки." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
              </StackPanel>

              <WrapPanel x:Name="Cards"/>

              <TextBlock Text="ЧТО СДЕЛАТЬ СЕЙЧАС" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold" Margin="2,14,0,10"/>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}">
                    <TextBlock Text="&#xE721;" Style="{StaticResource SettingIconGlyph}"/>
                  </Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Проверить файл или папку" Style="{StaticResource SettingName}"/>
                    <TextBlock Text="Перетащите что угодно в окно проверки: программа сама распакует архив, спросит пароль и решит, что отправлять на VirusTotal." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <Button x:Name="BtnScanFiles2" Grid.Column="2" Content="Открыть" Margin="14,0,0,0"/>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}">
                    <TextBlock Text="&#xE8A5;" Style="{StaticResource SettingIconGlyph}"/>
                  </Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Отчёты, улики и справка" Style="{StaticResource SettingName}"/>
                    <TextBlock Text="Сохранённые проверки, подробности по каждой тревоге и описание программы." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <Button x:Name="BtnReports"  Content="Отчёты"/>
                    <Button x:Name="BtnEvidence" Content="Улики"/>
                    <Button x:Name="BtnHelp"     Content="Справка" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>
            </StackPanel>
          </ScrollViewer>
        </TabItem>

        <!-- ========== ЗАЩИТА ========== -->
        <TabItem Header="Защита">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="30,26,30,24">
              <StackPanel Style="{StaticResource PageHead}">
                <TextBlock Text="Защита" Style="{StaticResource H1}"/>
                <TextBlock Text="Что программа делает постоянно, без вашего участия." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
              </StackPanel>

              <TextBlock Text="НАБЛЮДЕНИЕ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold" Margin="2,0,0,10"/>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE72E;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Аудит доступа к cookie" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="AuditSub" Text="Windows записывает, какая программа открыла базу cookie или паролей." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <CheckBox x:Name="TglAudit" Grid.Column="2" Style="{StaticResource Toggle}" Margin="14,0,0,0"/>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE81C;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Журнал запуска программ" Style="{StaticResource SettingName}"/>
                    <TextBlock Text="Без него не видно, кто запустил процесс и с какой командной строкой." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <Button x:Name="BtnProcAudit2" Grid.Column="2" Content="Включить" Margin="14,0,0,0"/>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE768;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Постоянная защита" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="GuardStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <CheckBox x:Name="TglGuard" Grid.Column="2" Style="{StaticResource Toggle}" Margin="14,0,0,0"/>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}" Margin="0,0,0,20">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE74D;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Сразу прятать подтверждённое вредоносное" Style="{StaticResource SettingName}"/>
                    <TextBlock Text="Только для файлов, которые VirusTotal уже знает как вредоносные: 5 и более детектов. Остальное — всегда с вашего согласия." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <CheckBox x:Name="ChkAutoNeutr" Grid.Column="2" Style="{StaticResource Toggle}" Margin="14,0,0,0"/>
                </Grid>
              </Border>

              <TextBlock Text="ПРОВЕРКИ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold" Margin="2,0,0,10"/>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE8A1;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Эталон системы" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="BaseStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <Button x:Name="BtnBaseNew"  Content="Снять заново"/>
                    <Button x:Name="BtnBaseDiff" Content="Сверить" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE774;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="VirusTotal" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="VtStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <Button x:Name="BtnVtScan" Content="Проверить файлы"/>
                    <Button x:Name="BtnVtKey"  Content="Ключ"/>
                    <Button x:Name="BtnVtSite" Content="Получить ключ" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}" Margin="0,0,0,20">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE968;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Безопасный сёрфинг через фильтрующий DNS" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="DnsStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <ComboBox x:Name="CmbDns" Width="210" Margin="0,0,8,0"/>
                    <Button x:Name="BtnDnsOn"   Content="Включить"/>
                    <Button x:Name="BtnDnsOff"  Content="Вернуть"/>
                    <Button x:Name="BtnDnsTest" Content="Проверить" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <TextBlock Text="ЕСЛИ ЧТО-ТО НЕ ВКЛЮЧАЕТСЯ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold" Margin="2,0,0,10"/>

              <Border Style="{StaticResource CardRow}" Margin="0,0,0,20">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE9D9;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Разобраться, что мешает" Style="{StaticResource SettingName}"/>
                    <TextBlock Text="Проверит права, политику аудита, службы, журнал безопасности и файлы браузеров — и назовёт причину, по которой переключатель не поддаётся." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <Button x:Name="BtnDiag" Grid.Column="2" Content="Проверить" Margin="14,0,0,0"/>
                </Grid>
              </Border>

              <!-- кнопки, оставшиеся от прежнего окна: обработчики
                   привязаны к ним, а управляют ими переключатели выше -->
              <StackPanel Orientation="Horizontal" Visibility="Collapsed">
                <Button x:Name="BtnAudit"/>
                <Button x:Name="BtnAuditOff"/>
                <Button x:Name="BtnGuardOn"/>
                <Button x:Name="BtnGuardOff"/>
                <Button x:Name="BtnProcAudit"/>
              </StackPanel>
            </StackPanel>
          </ScrollViewer>
        </TabItem>

        <!-- ========== МОНИТОР ========== -->
        <TabItem Header="Монитор">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Монитор" Style="{StaticResource H1}"/>
              <TextBlock Text="Живые события: кто прямо сейчас обращается к cookie и паролям." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnMon2" Content="Запустить монитор" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnMonClear" Content="Очистить" Style="{StaticResource Ghost}"/>
                  <CheckBox x:Name="ChkShowOk" Content="показывать обычные обращения браузера" Margin="12,0,0,0"/>
                </StackPanel>
                <TextBlock x:Name="MonStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridMon">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="ВРЕМЯ"   Binding="{Binding TimeText}" Width="78"/>
                  <DataGridTextColumn Header="УРОВЕНЬ" Binding="{Binding Severity}" Width="86"/>
                  <DataGridTextColumn Header="ТИП"     Binding="{Binding Kind}"     Width="100"/>
                  <DataGridTextColumn Header="СОБЫТИЕ" Binding="{Binding Title}"    Width="*"/>
                  <DataGridTextColumn Header="ПРОЦЕСС" Binding="{Binding Process}"  Width="210"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== НАХОДКИ ========== -->
        <TabItem Header="Находки">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Находки" Style="{StaticResource H1}"/>
              <TextBlock Text="Итог проверки системы. Щёлкните строку — справа появится разбор." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnScan2" Content="Проверить систему" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnSaveReport" Content="Сохранить отчёт" Style="{StaticResource Ghost}"/>
                  <CheckBox x:Name="ChkOnlyBad" Content="только важное" IsChecked="True" Margin="12,0,0,0"/>
                </StackPanel>
                <TextBlock x:Name="ScanStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridFind">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="УРОВЕНЬ" Binding="{Binding Severity}" Width="86"/>
                  <DataGridTextColumn Header="РАЗДЕЛ"  Binding="{Binding Area}"     Width="150"/>
                  <DataGridTextColumn Header="НАХОДКА" Binding="{Binding Title}"    Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ПРОЦЕССЫ ========== -->
        <TabItem Header="Процессы">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Процессы" Style="{StaticResource H1}"/>
              <TextBlock Text="Что сейчас запущено, кем подписано и откуда взялось." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnProcRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <CheckBox x:Name="ChkOnlyRisky" Content="только подозрительные" IsChecked="True" Margin="12,0,0,0"/>
                </StackPanel>
                <TextBlock x:Name="ProcStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridProc">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="РИСК"    Binding="{Binding Risk}"      Width="66"/>
                  <DataGridTextColumn Header="УРОВЕНЬ" Binding="{Binding Severity}"  Width="86"/>
                  <DataGridTextColumn Header="ИМЯ"     Binding="{Binding Name}"      Width="200"/>
                  <DataGridTextColumn Header="PID"     Binding="{Binding Id}"        Width="70"/>
                  <DataGridTextColumn Header="ПОДПИСЬ" Binding="{Binding Signature}" Width="240"/>
                  <DataGridTextColumn Header="ПУТЬ"    Binding="{Binding Path}"      Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== РАСШИРЕНИЯ ========== -->
        <TabItem Header="Расширения">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Расширения браузеров" Style="{StaticResource H1}"/>
              <TextBlock Text="Расширение с правом читать все сайты видит ваши сессии так же, как вы." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnExtRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnExtStore" Content="Открыть в магазине" Style="{StaticResource Ghost}"/>
                </StackPanel>
                <TextBlock x:Name="ExtStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridExt">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="УРОВЕНЬ"  Binding="{Binding Severity}" Width="86"/>
                  <DataGridTextColumn Header="БРАУЗЕР"  Binding="{Binding Browser}"  Width="95"/>
                  <DataGridTextColumn Header="НАЗВАНИЕ" Binding="{Binding Name}"     Width="260"/>
                  <DataGridTextColumn Header="ПРАВА"    Binding="{Binding Perms}"    Width="300"/>
                  <DataGridTextColumn Header="САЙТЫ"    Binding="{Binding Sites}"    Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== АВТОЗАПУСК ========== -->
        <TabItem Header="Автозапуск">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Автозапуск" Style="{StaticResource H1}"/>
              <TextBlock Text="Реестр, папки автозагрузки, задачи планировщика и службы." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <Button x:Name="BtnAutoRefresh" Content="Обновить" Style="{StaticResource Primary}" HorizontalAlignment="Left"/>
                <TextBlock x:Name="AutoStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridAuto">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="УРОВЕНЬ" Binding="{Binding Severity}" Width="86"/>
                  <DataGridTextColumn Header="ТИП"     Binding="{Binding Kind}"     Width="150"/>
                  <DataGridTextColumn Header="ИМЯ"     Binding="{Binding Name}"     Width="250"/>
                  <DataGridTextColumn Header="КОМАНДА" Binding="{Binding Command}"  Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ЗАПУСКИ ========== -->
        <TabItem Header="Запуски">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="История запусков" Style="{StaticResource H1}"/>
              <TextBlock Text="Что запускалось за последние часы и кто это запустил." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnRunRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <CheckBox x:Name="ChkRunOnlyBad" Content="только необычные" Margin="12,0,0,0"/>
                </StackPanel>
                <TextBlock x:Name="RunStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridRun">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="ВРЕМЯ"       Binding="{Binding TimeText}" Width="80"/>
                  <DataGridTextColumn Header="УРОВЕНЬ"     Binding="{Binding Severity}" Width="86"/>
                  <DataGridTextColumn Header="ПРОГРАММА"   Binding="{Binding Name}"     Width="200"/>
                  <DataGridTextColumn Header="ЗАПУЩЕНА ИЗ" Binding="{Binding Parent}"   Width="170"/>
                  <DataGridTextColumn Header="КОМАНДА"     Binding="{Binding Command}"  Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== КАРАНТИН ========== -->
        <TabItem Header="Карантин">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Карантин" Style="{StaticResource H1}"/>
              <TextBlock Text="Спрятанные файлы. Запустить их нельзя, вернуть — можно, байт в байт." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnQuarRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnQuarRestore" Content="Восстановить"/>
                  <Button x:Name="BtnQuarDelete"  Content="Удалить насовсем" Style="{StaticResource Danger}"/>
                  <Button x:Name="BtnQuarFolder"  Content="Папка карантина" Style="{StaticResource Ghost}"/>
                </StackPanel>
                <TextBlock x:Name="QuarStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridQuar">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="В КАРАНТИНЕ С" Binding="{Binding QuarantinedText}" Width="150"/>
                  <DataGridTextColumn Header="ФАЙЛ"          Binding="{Binding Name}"           Width="220"/>
                  <DataGridTextColumn Header="ПРИЧИНА"       Binding="{Binding Reason}"         Width="240"/>
                  <DataGridTextColumn Header="БЫЛ ПО ПУТИ"   Binding="{Binding OriginalPath}"   Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ДОВЕРЕННЫЕ ========== -->
        <TabItem Header="Доверенные">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Доверенные" Style="{StaticResource H1}"/>
              <TextBlock Text="То, про что вы уже разобрались. Столбец «действует на» показывает, насколько широко." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <Grid>
                <StackPanel Orientation="Horizontal">
                  <Button x:Name="BtnTrustRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnTrustRevoke" Content="Снять доверие" Style="{StaticResource Danger}"/>
                </StackPanel>
                <TextBlock x:Name="TrustStats" Text="" Style="{StaticResource Sub}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Style="{StaticResource Card}" Padding="4" Margin="0">
              <DataGrid x:Name="GridTrust">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="ОБЛАСТЬ"      Binding="{Binding Kind}"      Width="200"/>
                  <DataGridTextColumn Header="НАЗВАНИЕ"     Binding="{Binding Name}"      Width="200"/>
                  <DataGridTextColumn Header="ДЕЙСТВУЕТ НА" Binding="{Binding Covers}"    Width="*"/>
                  <DataGridTextColumn Header="ПРИЧИНА"      Binding="{Binding Note}"      Width="200"/>
                  <DataGridTextColumn Header="ДОБАВЛЕНО"    Binding="{Binding AddedText}" Width="140"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ЖУРНАЛ ========== -->
        <TabItem Header="Журнал">
          <DockPanel Margin="30,26,30,22">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="Журнал" Style="{StaticResource H1}"/>
              <TextBlock Text="Что программа делала и когда." Style="{StaticResource Sub}" Margin="0,5,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource Card}" Padding="14,10" Margin="0,0,0,10">
              <StackPanel Orientation="Horizontal">
                <Button x:Name="BtnLogRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                <Button x:Name="BtnLogFolder" Content="Папка журналов" Style="{StaticResource Ghost}"/>
              </StackPanel>
            </Border>
            <TextBox x:Name="LogBox" Style="{StaticResource Mono}" VerticalScrollBarVisibility="Auto"
                     HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
          </DockPanel>
        </TabItem>
      </TabControl>

      <!-- ========== разбор выбранной строки ========== -->
      <Border x:Name="Inspector" Grid.Column="2" Width="412" Background="#15181E"
              BorderBrush="#232832" BorderThickness="1,0,0,0" Visibility="Collapsed">
        <DockPanel>
          <Grid DockPanel.Dock="Top" Margin="20,18,14,0">
            <StackPanel Margin="0,0,34,0">
              <TextBlock x:Name="InspKind" Text="ПОДРОБНОСТИ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold"/>
              <TextBlock x:Name="InspTitle" Text="" Style="{StaticResource H2}" FontSize="15" TextWrapping="Wrap" Margin="0,6,0,0"/>
            </StackPanel>
            <Button x:Name="BtnInspClose" Content="&#xE8BB;" Style="{StaticResource CaptionBtn}" Width="30" Height="30"
                    HorizontalAlignment="Right" VerticalAlignment="Top"/>
          </Grid>

          <Border DockPanel.Dock="Top" Height="1" Background="#232832" Margin="20,16,20,0"/>

          <StackPanel DockPanel.Dock="Top" Margin="20,14,20,0">
            <TextBlock Text="ЧТО МОЖНО СДЕЛАТЬ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold" Margin="0,0,0,9"/>
            <WrapPanel>
              <Button x:Name="BtnTrust"    Content="Доверять" Style="{StaticResource Good}" Margin="0,0,7,7"/>
              <Button x:Name="BtnExplorer" Content="В проводнике" Margin="0,0,7,7"/>
              <Button x:Name="BtnWeb"      Content="Искать в сети" Margin="0,0,7,7"/>
              <Button x:Name="BtnVT"       Content="VirusTotal" Margin="0,0,7,7"/>
              <Button x:Name="BtnAsk"      Content="Спросить у ИИ" Margin="0,0,7,7"/>
              <Button x:Name="BtnCopy"     Content="Копировать" Margin="0,0,7,7"/>
            </WrapPanel>
            <TextBlock Text="НЕОБРАТИМОЕ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold" Margin="0,8,0,9"/>
            <WrapPanel>
              <Button x:Name="BtnKill"  Content="Завершить процесс" Margin="0,0,7,7"/>
              <Button x:Name="BtnQuar"  Content="В карантин" Margin="0,0,7,7"/>
              <Button x:Name="BtnNeutr" Content="Обезвредить" Style="{StaticResource Danger}" Margin="0,0,7,7"/>
            </WrapPanel>
          </StackPanel>

          <Border Margin="20,14,20,20">
            <TextBox x:Name="DetailBox" Style="{StaticResource Mono}" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
          </Border>
        </DockPanel>
      </Border>
    </Grid>

    <!-- ===================== СТРОКА СОСТОЯНИЯ ===================== -->
    <Border Grid.Row="2" Background="#15181E" BorderBrush="#232832" BorderThickness="0,1,0,0" Padding="18,8">
      <Grid>
        <TextBlock x:Name="StatusText" Text="Готов" Style="{StaticResource Sub}" VerticalAlignment="Center"/>
        <ProgressBar x:Name="Progress" Width="190" Height="4" HorizontalAlignment="Right"
                     Visibility="Collapsed" IsIndeterminate="True"/>
      </Grid>
    </Border>
  </Grid>
  </Border>
</Window>
'@
