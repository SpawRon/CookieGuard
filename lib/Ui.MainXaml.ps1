# ============================================================
#  CookieGuard - Ui.MainXaml.ps1
#  Разметка главного окна.
#
#  Раскладка прежняя: слева столбец разделов, справа страница.
#  Выбрано не ради похожести на «Параметры» — человек, который
#  открыл программу после взлома, не должен ещё и разбираться,
#  где у неё что. Он уже знает.
#
#  Три полосы:
#    слева  — разделы,
#    в центре — страница,
#    справа — разбор выбранной строки.
#  Раньше разбор жил узкой полосой внизу: в неё не помещалось
#  ни подробностей, ни кнопок, и половина действий терялась.
#
#  Вид «Монолит»: разделы пронумерованы, и тот же номер
#  стоит над заголовком страницы; панель инструментов и таблица
#  срастаются в один блок по общей линии; обзор открывается
#  тремя крупными числами — критично, внимание, в карантине.
#
#  Имена всех прежних элементов сохранены: к ним привязаны
#  обработчики в CookieGuard.ps1. Порядок строк в списке разделов
#  тоже: по нему построена карта «строка → страница».
# ============================================================

$script:CgMainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="CookieGuard" Height="880" Width="1340" MinHeight="660" MinWidth="1080"
        WindowStyle="None" Background="#0C0D10" WindowStartupLocation="CenterScreen">
  <shell:WindowChrome.WindowChrome>
    <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0"
                        CornerRadius="0" UseAeroCaptionButtons="False"/>
  </shell:WindowChrome.WindowChrome>

  <Window.Resources>
<!--THEME-->

    <!-- заголовок группы в списке разделов: начинается там же,
         где названия разделов, а не над номерами -->
    <Style x:Key="NavHeader" TargetType="ListBoxItem">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsHitTestVisible" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <TextBlock Text="{TemplateBinding Content}" Foreground="{StaticResource Muted}" FontSize="10.5"
                       FontFamily="{StaticResource FontDisplay}" Margin="44,18,0,8"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- строка настройки: значок, название, пояснение, управление -->
    <Style x:Key="SettingIcon" TargetType="Border">
      <Setter Property="Width" Value="32"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="{StaticResource StrongLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Margin" Value="0,0,16,0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="SettingIconGlyph" TargetType="TextBlock" BasedOn="{StaticResource Glyph}">
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
    </Style>
    <Style x:Key="SettingName" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="FontFamily" Value="{StaticResource FontBody}"/>
      <Setter Property="FontSize" Value="13.5"/>
    </Style>

    <Style x:Key="PageHead" TargetType="StackPanel">
      <Setter Property="Margin" Value="0,0,0,20"/>
    </Style>

    <!-- панель инструментов над таблицей: стоит вплотную к ней
         и делит с ней линию, так что вместе они — один блок -->
    <Style x:Key="ToolStrip" TargetType="Border" BasedOn="{StaticResource Card}">
      <Setter Property="Padding" Value="12,8"/>
      <Setter Property="Margin"  Value="0,0,0,-1"/>
      <Setter Property="Background" Value="{StaticResource NavBg}"/>
    </Style>
    <Style x:Key="GridBox" TargetType="Border" BasedOn="{StaticResource Card}">
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Margin"  Value="0"/>
    </Style>
    <!-- Сводка под таблицей, как показания под шкалой прибора.
         Справа от кнопок ей не хватало места: длинная строка
         «критично: … внимание: … заметки: …» наезжала на вкладки.
         Пока сводки нет, полосы нет. -->
    <Style x:Key="Readout" TargetType="Border" BasedOn="{StaticResource Card}">
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Margin"  Value="0,-1,0,0"/>
      <Setter Property="Background" Value="{StaticResource NavBg}"/>
      <Style.Triggers>
        <DataTrigger Binding="{Binding Child.Text, RelativeSource={RelativeSource Self}}" Value="">
          <Setter Property="Visibility" Value="Collapsed"/>
        </DataTrigger>
      </Style.Triggers>
    </Style>

    <!-- ячейка «уровень» во всех таблицах -->
    <DataTemplate x:Key="SevCell">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
        <Rectangle Style="{StaticResource SevMark}"/>
        <TextBlock Text="{Binding Severity}" Style="{StaticResource PillTextAuto}"/>
      </StackPanel>
    </DataTemplate>

    <!-- подпись над крупным числом обзора -->
    <Style x:Key="HeroLabel" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontDisplay}"/>
      <Setter Property="FontSize"   Value="11"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="HeroNote" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontMono}"/>
      <Setter Property="FontSize"   Value="11.5"/>
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="Margin"     Value="0,4,0,0"/>
    </Style>
  </Window.Resources>

  <Border BorderBrush="#1A1D22" BorderThickness="1">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="40"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- ===================== ЗАГОЛОВОК ОКНА ===================== -->
    <Border Grid.Row="0" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
      <!-- Три столбца, а не три слоя друг на друге: без прав
           администратора надпись слева от плашек длиннее, и она
           заезжала на поле поиска. -->
      <Grid x:Name="TitleBar" Background="Transparent">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="14,0,0,0">
          <!-- щит с печеньем — тот же знак, что на значке программы,
               только плоский: на плите объём был бы чужим -->
          <Viewbox Width="20" Height="20">
            <Canvas Width="24" Height="24">
              <Path Data="M12,2 L20,5 L20,11 C20,16.5 16.6,20.4 12,22 C7.4,20.4 4,16.5 4,11 L4,5 Z" Fill="{StaticResource Accent}"/>
              <Ellipse Canvas.Left="7.7"   Canvas.Top="7.3"   Width="8.6" Height="8.6" Fill="#F3D9A8"/>
              <Ellipse Canvas.Left="9.65"  Canvas.Top="9.55"  Width="1.9" Height="1.9" Fill="#3A2416"/>
              <Ellipse Canvas.Left="12.35" Canvas.Top="10.35" Width="1.9" Height="1.9" Fill="#3A2416"/>
              <Ellipse Canvas.Left="10.55" Canvas.Top="12.25" Width="1.9" Height="1.9" Fill="#3A2416"/>
            </Canvas>
          </Viewbox>
          <TextBlock Text="COOKIEGUARD" FontFamily="{StaticResource FontDisplay}" FontWeight="SemiBold" FontSize="13.5"
                     Margin="10,0,0,0" VerticalAlignment="Center"/>
        </StackPanel>

        <!-- Поиск по разделам и по тому, что уже найдено. Окно на
             одиннадцать разделов и таблицы на сотни строк без поиска
             заставляют помнить, где что лежит. -->
        <Grid Grid.Column="1" HorizontalAlignment="Stretch" VerticalAlignment="Center" MaxWidth="420" Margin="24,0">
          <TextBox x:Name="SearchBox" Height="28" MinHeight="0" Padding="29,0,9,0" VerticalContentAlignment="Center"
                   Background="{StaticResource WinBg}" BorderBrush="{StaticResource Line}" FontSize="12.5"/>
          <TextBlock Text="&#xE721;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12"
                     Foreground="{StaticResource Muted}" VerticalAlignment="Center" Margin="10,0,0,0" IsHitTestVisible="False"/>
          <TextBlock x:Name="SearchHint" Text="Найти в разделах и находках" Style="{StaticResource Sub}"
                     FontSize="12.5" VerticalAlignment="Center" Margin="31,0,0,1" IsHitTestVisible="False"/>
          <Popup x:Name="SearchPop" PlacementTarget="{Binding ElementName=SearchBox}" Placement="Bottom"
                 AllowsTransparency="True" StaysOpen="False" Width="470" HorizontalOffset="-25">
            <Border Background="{StaticResource ControlBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1"
                    CornerRadius="3" Padding="4" Margin="0,5,0,0">
              <Border.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="4" Opacity="0.55" Color="#000000"/></Border.Effect>
              <ListBox x:Name="SearchList" Background="Transparent" BorderThickness="0" MaxHeight="360"/>
            </Border>
          </Popup>
        </Grid>

        <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock x:Name="ChipAdmin" Text="" Style="{StaticResource Sub}" FontFamily="{StaticResource FontDisplay}"
                     FontSize="11" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <Border CornerRadius="2" Padding="10,3" Margin="0,0,8,0" BorderBrush="{StaticResource Line}" BorderThickness="1">
            <TextBlock x:Name="ChipAudit" Text="" FontFamily="{StaticResource FontDisplay}" FontSize="11" VerticalAlignment="Center"/>
          </Border>
          <Border CornerRadius="2" Padding="10,3" Margin="0,0,14,0" BorderBrush="{StaticResource Line}" BorderThickness="1">
            <TextBlock x:Name="ChipMon" Text="" FontFamily="{StaticResource FontDisplay}" FontSize="11" VerticalAlignment="Center"/>
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
        <!-- Ширина столбца — GridLength, её анимировать нечем.
             Поэтому столбец подстраивается под панель, а едет панель. -->
        <ColumnDefinition x:Name="NavCol" Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <!-- ========== столбец разделов ========== -->
      <Border x:Name="NavPanel" Grid.Column="0" Width="252" Background="{StaticResource NavBg}"
              BorderBrush="{StaticResource Line}" BorderThickness="0,0,1,0">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top" Margin="12,10,12,8">
            <Button x:Name="BtnNavToggle" Content="&#xE700;" Style="{StaticResource IconBtn}"
                    HorizontalAlignment="Left" Margin="0,0,0,10" ToolTip="Свернуть столбец разделов"/>
            <StackPanel x:Name="NavActions">
              <Button x:Name="BtnScan" Content="Проверить систему" Style="{StaticResource Primary}" Height="40"
                      HorizontalContentAlignment="Left" Margin="0,0,0,8"/>
              <Button x:Name="BtnScanFiles" Content="Проверить файл или папку" Height="36"
                      HorizontalContentAlignment="Left" Margin="0,0,0,0"/>
              <Button x:Name="BtnMon" Content="Запустить монитор" Style="{StaticResource Ghost}" Height="36"
                      HorizontalContentAlignment="Left" Margin="0,8,0,0"/>
            </StackPanel>
            <!-- Те же три действия, когда столбец свёрнут. Прятать их
                 совсем нельзя: «Проверить систему» — главная кнопка окна. -->
            <StackPanel x:Name="NavActionsMini" Visibility="Collapsed">
              <Button x:Name="BtnScanMini" Content="&#xE721;" Style="{StaticResource IconBtn}" Margin="0,0,0,6" ToolTip="Проверить систему"/>
              <Button x:Name="BtnScanFilesMini" Content="&#xE8B7;" Style="{StaticResource IconBtn}" Margin="0,0,0,6" ToolTip="Проверить файл или папку"/>
              <Button x:Name="BtnMonMini" Content="&#xE768;" Style="{StaticResource IconBtn}" Margin="0" ToolTip="Запустить монитор"/>
            </StackPanel>
          </StackPanel>
          <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="0,8,0,10">
            <!-- Номер вместо значка: тот же номер стоит над заголовком
                 страницы, и по нему видно, где ты, даже в свёрнутом
                 столбце. -->
            <ListBox x:Name="Nav" Style="{StaticResource NavList}" ItemContainerStyle="{StaticResource NavItem}">
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="01" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Обзор" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="02" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Защита" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="03" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Проверка файлов" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>

              <ListBoxItem x:Name="NavHeadWatch" Content="НАБЛЮДЕНИЕ" Style="{StaticResource NavHeader}"/>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="04" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Монитор" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="05" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Находки" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="06" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Процессы" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="07" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Расширения" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="08" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Автозапуск" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="09" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Запуски" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>

              <ListBoxItem x:Name="NavHeadAnalyse" Content="РАЗБОР" Style="{StaticResource NavHeader}"/>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="10" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Карантин" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="11" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Доверенные" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
              <ListBoxItem>
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="12" Style="{StaticResource NavNum}"/>
                  <TextBlock Text="Журнал" Tag="navlabel" VerticalAlignment="Center"/>
                </StackPanel>
              </ListBoxItem>
            </ListBox>
          </ScrollViewer>
        </DockPanel>
      </Border>

      <!-- ========== страницы ========== -->
      <TabControl x:Name="Tabs" Grid.Column="1" Background="{StaticResource WinBg}" BorderThickness="0">
        <TabControl.RenderTransform><TranslateTransform/></TabControl.RenderTransform>
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
            <StackPanel>
              <!-- шапка: заголовок говорит итог, а не имя раздела -->
              <Border BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1" Padding="32,26,32,22">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <StackPanel>
                    <TextBlock Text="01 — ОБЗОР" Style="{StaticResource Kicker}"/>
                    <TextBlock x:Name="HeroHead" Text="Обзор" Style="{StaticResource H1}" TextWrapping="Wrap"/>
                    <TextBlock x:Name="HeroSub" Text="Состояние наблюдения и итог последней проверки." Style="{StaticResource Sub}"
                               FontSize="13" Foreground="{StaticResource TextDim}" Margin="0,8,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Bottom" Margin="16,0,0,0">
                    <Button x:Name="BtnFixAll2" Content="Исправить всё" Style="{StaticResource Good}" Height="36" Visibility="Collapsed"/>
                    <Button x:Name="HeroGo" Content="Разобрать находки  →" Style="{StaticResource Primary}" Height="36" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <!-- Монолит: три числа и линейка под ними. Крупно — то,
                   ради чего программу открывают; всё прочее мельче. -->
              <Border BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
                <StackPanel>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Border Grid.Column="0" BorderBrush="{StaticResource Line}" BorderThickness="0,0,1,0" Padding="32,22,24,16">
                      <StackPanel>
                        <StackPanel Orientation="Horizontal">
                          <Rectangle Width="8" Height="8" Fill="{StaticResource Crit}" Margin="0,0,8,0" VerticalAlignment="Center"/>
                          <TextBlock Text="КРИТИЧНО" Style="{StaticResource HeroLabel}" Foreground="{StaticResource Crit}"/>
                        </StackPanel>
                        <TextBlock x:Name="HeroCrit" Text="—" Style="{StaticResource BigNum}"/>
                        <TextBlock Text="разберите первыми" Style="{StaticResource HeroNote}"/>
                      </StackPanel>
                    </Border>
                    <Border Grid.Column="1" BorderBrush="{StaticResource Line}" BorderThickness="0,0,1,0" Padding="32,22,24,16">
                      <StackPanel>
                        <StackPanel Orientation="Horizontal">
                          <Rectangle Width="8" Height="8" Fill="{StaticResource Warn}" Margin="0,0,8,0" VerticalAlignment="Center"/>
                          <TextBlock Text="ВНИМАНИЕ" Style="{StaticResource HeroLabel}" Foreground="{StaticResource Warn}"/>
                        </StackPanel>
                        <TextBlock x:Name="HeroWarn" Text="—" Style="{StaticResource BigNum}"/>
                        <TextBlock Text="посмотрите, когда будет время" Style="{StaticResource HeroNote}"/>
                      </StackPanel>
                    </Border>
                    <Border Grid.Column="2" Padding="32,22,24,16">
                      <StackPanel>
                        <StackPanel Orientation="Horizontal">
                          <Rectangle Width="8" Height="8" Stroke="{StaticResource TextDim}" StrokeThickness="1" Margin="0,0,8,0" VerticalAlignment="Center"/>
                          <TextBlock Text="В КАРАНТИНЕ" Style="{StaticResource HeroLabel}" Foreground="{StaticResource TextDim}"/>
                        </StackPanel>
                        <TextBlock x:Name="HeroQuar" Text="—" Style="{StaticResource BigNum}" Foreground="{StaticResource TextDim}"/>
                        <TextBlock Text="вернуть можно байт в байт" Style="{StaticResource HeroNote}"/>
                      </StackPanel>
                    </Border>
                  </Grid>
                  <Grid Margin="32,0,32,20">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <!-- Доли критичного и «внимания» в итоге проверки.
                         До первой проверки линейка серая целиком. -->
                    <Grid Height="6" VerticalAlignment="Center">
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition x:Name="HeroBarCrit" Width="0*"/>
                        <ColumnDefinition x:Name="HeroBarWarn" Width="0*"/>
                        <ColumnDefinition x:Name="HeroBarRest" Width="1*"/>
                      </Grid.ColumnDefinitions>
                      <Border Grid.Column="0" Background="{StaticResource Crit}" Margin="0,0,2,0"/>
                      <Border Grid.Column="1" Background="{StaticResource Warn}"/>
                      <Border Grid.Column="2" Background="{StaticResource ControlBg}"/>
                    </Grid>
                    <TextBlock x:Name="HeroTotal" Grid.Column="1" Text="проверки ещё не было" Style="{StaticResource Stat}" Margin="14,0,0,0"/>
                  </Grid>
                </StackPanel>
              </Border>

              <StackPanel Margin="32,22,32,26">
                <TextBlock Text="СОСТОЯНИЕ" Style="{StaticResource GroupLabel}"/>
                <!-- Приборная панель: ячейки в ровной сетке, соседние
                     делят рамку. Ячейки собирает Update-Cards. -->
                <UniformGrid x:Name="Cards" Columns="3" Margin="0,0,1,1"/>

                <TextBlock Text="ЧТО СДЕЛАТЬ СЕЙЧАС" Style="{StaticResource GroupLabel}" Margin="0,26,0,10"/>

                <Border Style="{StaticResource CardRow}">
                  <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <Border Grid.Column="0" Style="{StaticResource SettingIcon}">
                      <TextBlock Text="&#xE721;" Style="{StaticResource SettingIconGlyph}"/>
                    </Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                      <TextBlock Text="Проверить файл или папку" Style="{StaticResource SettingName}"/>
                      <TextBlock Text="Перетащите файл или папку в любое место этого окна — программа сама распакует архив, спросит пароль и решит, что отправлять на VirusTotal." Style="{StaticResource Sub}" Margin="0,3,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                    <Button x:Name="BtnScanFiles2" Grid.Column="2" Content="Перейти" Margin="14,0,0,0"/>
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
                      <Button x:Name="BtnHelp"     Content="Справка" Style="{StaticResource Ghost}" Margin="0"/>
                    </StackPanel>
                  </Grid>
                </Border>
              </StackPanel>
            </StackPanel>
          </ScrollViewer>
        </TabItem>

        <!-- ========== ЗАЩИТА ========== -->
        <TabItem Header="Защита">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="32,26,32,24">
              <StackPanel Style="{StaticResource PageHead}">
                <TextBlock Text="02 — ЗАЩИТА" Style="{StaticResource Kicker}"/>
                <TextBlock Text="Защита" Style="{StaticResource H1}"/>
                <TextBlock Text="Что программа делает постоянно, без вашего участия." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
              </StackPanel>

              <TextBlock Text="ГЛАВНОЕ" Style="{StaticResource GroupLabel}"/>

              <!-- Один переключатель на всё. Под ним — список того, что он
                   включает, с живым состоянием каждой части: так видно не
                   «защита включена», а что именно работает и что нет. -->
              <Border Style="{StaticResource CardRow}" Margin="0,0,0,26">
                <StackPanel>
                  <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xEA18;" Style="{StaticResource SettingIconGlyph}"/></Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                      <TextBlock Text="Автозащита" Style="{StaticResource SettingName}"/>
                      <TextBlock x:Name="AutoSub" Text="Всё наблюдение одним переключателем. Помнит, что включено, стартует вместе с Windows и само включает обратно то, что выключили." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnAutoMore" Grid.Column="2" Content="Что включено ▾" Style="{StaticResource Ghost}" Margin="14,0,0,0"/>
                    <CheckBox x:Name="TglAuto" Grid.Column="3" Style="{StaticResource Toggle}" Margin="14,0,0,0"/>
                  </Grid>
                  <StackPanel x:Name="AutoPartsBox" Visibility="Collapsed" Margin="0,16,0,0">
                    <Border Height="1" Background="{StaticResource Line}" Margin="0,0,0,12"/>
                    <StackPanel x:Name="AutoParts"/>
                    <TextBlock x:Name="AutoPartsHint" Style="{StaticResource Sub}" Margin="0,10,0,0"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <TextBlock Text="НАБЛЮДЕНИЕ ПО ОТДЕЛЬНОСТИ" Style="{StaticResource GroupLabel}"/>

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

              <Border Style="{StaticResource CardRow}" Margin="0,0,0,26">
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

              <TextBlock Text="ПРОВЕРКИ" Style="{StaticResource GroupLabel}"/>

              <Border Style="{StaticResource CardRow}">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE8A1;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Эталон системы" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="BaseStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <Button x:Name="BtnBaseNew"  Content="Снять заново" Style="{StaticResource Ghost}"/>
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
                    <Button x:Name="BtnVtKey"  Content="Ключ" Style="{StaticResource Ghost}"/>
                    <Button x:Name="BtnVtSite" Content="Получить ключ" Style="{StaticResource Ghost}" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <Border Style="{StaticResource CardRow}" Margin="0,0,0,26">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*" MinWidth="200"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE968;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Безопасный сёрфинг через фильтрующий DNS" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="DnsStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <ComboBox x:Name="CmbDns" Width="170" Margin="0,0,8,0"/>
                    <Button x:Name="BtnDnsOn"   Content="Включить"/>
                    <Button x:Name="BtnDnsOff"  Content="Вернуть" Style="{StaticResource Ghost}"/>
                    <Button x:Name="BtnDnsTest" Content="Проверить" Style="{StaticResource Ghost}" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <TextBlock Text="ОБНОВЛЕНИЕ" Style="{StaticResource GroupLabel}"/>

              <Border Style="{StaticResource CardRow}" Margin="0,0,0,26">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE896;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Версия программы" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="UpdStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                    <!-- Откуда запущена эта копия и откуда придёт обновление.
                         Без этого правки, сделанные в другой папке или не
                         отправленные на GitHub, выглядят как «обновление не
                         работает», хотя кнопка честно ставит то, что видит. -->
                    <TextBlock x:Name="UpdWhere" Text="" Style="{StaticResource Stat}" FontSize="11" TextWrapping="Wrap"
                               LineHeight="17" Margin="0,6,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0" VerticalAlignment="Center">
                    <Button x:Name="BtnUpdCheck"   Content="Проверить"/>
                    <Button x:Name="BtnUpdInstall" Content="Обновить" Style="{StaticResource Primary}"/>
                    <Button x:Name="BtnUpdToken"   Content="Ключ GitHub" Style="{StaticResource Ghost}" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <TextBlock Text="ИНТЕРФЕЙС" Style="{StaticResource GroupLabel}"/>

              <!-- Подпись двуязычная: найти переключатель должен и тот,
                   кто не читает язык, на котором сейчас окно. -->
              <Border Style="{StaticResource CardRow}" Margin="0,0,0,26">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xE8C1;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Язык интерфейса · Interface language" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="LangSub" Text="Новый язык включится после перезапуска окна." Style="{StaticResource Sub}" Margin="0,3,0,0"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <ComboBox x:Name="CmbLang" Width="130" Margin="0">
                      <ComboBoxItem Content="Русский" Tag="ru"/>
                      <ComboBoxItem Content="English" Tag="en"/>
                    </ComboBox>
                    <Button x:Name="BtnLangRestart" Content="Перезапустить" Style="{StaticResource Primary}" Margin="8,0,0,0" Visibility="Collapsed"/>
                  </StackPanel>
                </Grid>
              </Border>

              <TextBlock Text="БРАУЗЕР" Style="{StaticResource GroupLabel}"/>

              <!-- Свой блокировщик рекламы: расширение из папки adblock.
                   Браузер подключает его только руками человека — кнопка
                   готовит всё и открывает нужную страницу. -->
              <Border Style="{StaticResource CardRow}" Margin="0,0,0,26">
                <Grid>
                  <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*" MinWidth="200"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Style="{StaticResource SettingIcon}"><TextBlock Text="&#xEA18;" Style="{StaticResource SettingIconGlyph}"/></Border>
                  <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="Блокировщик рекламы" Style="{StaticResource SettingName}"/>
                    <TextBlock x:Name="AdStats" Text="" Style="{StaticResource Sub}" Margin="0,3,0,0" TextWrapping="Wrap"/>
                  </StackPanel>
                  <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="14,0,0,0">
                    <Button x:Name="BtnAdInstall" Content="Подключить к браузеру" Style="{StaticResource Primary}"/>
                    <Button x:Name="BtnAdLists"   Content="Обновить списки"/>
                    <Button x:Name="BtnAdFolder"  Content="Папка" Style="{StaticResource Ghost}" Margin="0"/>
                  </StackPanel>
                </Grid>
              </Border>

              <TextBlock Text="ЕСЛИ ЧТО-ТО НЕ ВКЛЮЧАЕТСЯ" Style="{StaticResource GroupLabel}"/>

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

        <!-- ========== ПРОВЕРКА ФАЙЛОВ ==========
             Раньше это было отдельное окно: открыть, перетащить, закрыть.
             Теперь файл можно бросить в любое место главного окна —
             оно само переключится сюда. -->
        <TabItem Header="Проверка файлов">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="03 — ПРОВЕРКА ФАЙЛОВ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Проверка файлов" Style="{StaticResource H1}"/>
              <TextBlock Text="Бросьте файл или папку в любое место окна. Архив программа распакует сама, пароль спросит, подписанное известным издателем пропустит." Style="{StaticResource Sub}" Margin="0,6,0,0" TextWrapping="Wrap"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <Grid>
                <WrapPanel>
                  <Button x:Name="SbAddFiles"  Content="Выбрать файлы" Style="{StaticResource Primary}"/>
                  <Button x:Name="SbAddFolder" Content="Выбрать папку"/>
                  <Button x:Name="SbClear"     Content="Очистить" Style="{StaticResource Ghost}"/>
                  <CheckBox x:Name="SbDeep" Content="заглядывать в архивы" IsChecked="True" Margin="12,0,0,0"/>
                </WrapPanel>
                <Button x:Name="SbCheck" Content="Проверить на VirusTotal" Style="{StaticResource Primary}" HorizontalAlignment="Right" Margin="0"/>
              </Grid>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <Grid>
                <TextBlock x:Name="SbStatus" Text="Пусто" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis" Margin="0,0,210,0"/>
                <ProgressBar x:Name="SbProgress" Width="190" Height="2" HorizontalAlignment="Right" Visibility="Collapsed" IsIndeterminate="True"/>
              </Grid>
            </Border>
            <Grid>
              <Border x:Name="SbDropHint" Style="{StaticResource GridBox}" Background="{StaticResource WinBg}">
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Margin="20">
                  <Border Width="72" Height="72" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" HorizontalAlignment="Center">
                    <TextBlock Text="&#xE8B5;" Style="{StaticResource Glyph}" FontSize="30" Foreground="{StaticResource Accent}"/>
                  </Border>
                  <TextBlock Text="Перетащите сюда файл или папку" Style="{StaticResource H2}" HorizontalAlignment="Center" Margin="0,22,0,0"/>
                  <TextBlock Text="Или нажмите «Выбрать файлы». Наружу уходит только отпечаток SHA-256 — сам файл никуда не загружается."
                             Style="{StaticResource Sub}" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" MaxWidth="460" Margin="0,9,0,0"/>
                </StackPanel>
              </Border>
              <Border x:Name="SbListBox" Style="{StaticResource GridBox}" Visibility="Collapsed">
                <DataGrid x:Name="SbGrid">
                  <DataGrid.Columns>
                    <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" CellTemplate="{StaticResource SevCell}"/>
                    <DataGridTextColumn Header="ФАЙЛ"    Binding="{Binding Display}"  Width="2*" MinWidth="180"/>
                    <DataGridTextColumn Header="РАЗМЕР"  Binding="{Binding SizeText}" Width="85"/>
                    <DataGridTextColumn Header="ЧТО ЭТО" Binding="{Binding KindText}" Width="135"/>
                    <DataGridTextColumn Header="ПОДПИСЬ" Binding="{Binding SignText}" Width="150"/>
                    <DataGridTextColumn Header="ВЕРДИКТ" Binding="{Binding Verdict}"  Width="3*" MinWidth="200"/>
                  </DataGrid.Columns>
                </DataGrid>
              </Border>
            </Grid>
          </DockPanel>
        </TabItem>

        <!-- ========== МОНИТОР ========== -->
        <TabItem Header="Монитор">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="04 — МОНИТОР" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Кто трогает cookie и пароли" Style="{StaticResource H1}"/>
              <TextBlock Text="Живые события: кто прямо сейчас обращается к cookie и паролям." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnMon2" Content="Запустить монитор" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnMonClear" Content="Очистить" Style="{StaticResource Ghost}"/>
                  <CheckBox x:Name="ChkShowOk" Content="показывать обычные обращения браузера" Margin="12,0,0,0"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="MonStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridMon">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="ВРЕМЯ"   Binding="{Binding TimeText}" Width="104">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/><Setter Property="Foreground" Value="{StaticResource Muted}"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                  <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" SortMemberPath="Order" CellTemplate="{StaticResource SevCell}"/>
                  <DataGridTextColumn Header="ТИП"     Binding="{Binding Kind}"     Width="100"/>
                  <DataGridTextColumn Header="СОБЫТИЕ" Binding="{Binding Title}"    Width="*"/>
                  <DataGridTextColumn Header="ПРОЦЕСС" Binding="{Binding Process}"  Width="210">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== НАХОДКИ ========== -->
        <TabItem Header="Находки">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="05 — НАХОДКИ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Находки" Style="{StaticResource H1}"/>
              <TextBlock Text="Итог проверки системы. Щёлкните строку — справа появится разбор." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnScan2" Content="Проверить систему" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnFixAll" Content="Исправить всё" Style="{StaticResource Good}"/>
                  <Button x:Name="BtnSaveReport" Content="Сохранить отчёт" Style="{StaticResource Ghost}"/>
                  <!-- Галочка «только важное» умела два состояния из
                       четырёх нужных. Оставлена скрытой: на неё ссылается
                       разбор, который показывает все строки подряд. -->
                  <CheckBox x:Name="ChkOnlyBad" Content="только важное" IsChecked="True" Visibility="Collapsed" Width="0"/>
                  <Border Width="1" Background="{StaticResource Line}" Margin="2,4,6,4"/>
                  <RadioButton x:Name="TabFindBad"  Style="{StaticResource SegTab}" Content="Важное" IsChecked="True" GroupName="FindFilter"/>
                  <RadioButton x:Name="TabFindCrit" Style="{StaticResource SegTab}" Content="Критично" GroupName="FindFilter"/>
                  <RadioButton x:Name="TabFindWarn" Style="{StaticResource SegTab}" Content="Внимание" GroupName="FindFilter"/>
                  <RadioButton x:Name="TabFindAll"  Style="{StaticResource SegTab}" Content="Все" GroupName="FindFilter"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="ScanStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridFind">
                <DataGrid.Columns>
                  <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" SortMemberPath="Order" CellTemplate="{StaticResource SevCell}"/>
                  <DataGridTextColumn Header="РАЗДЕЛ"  Binding="{Binding Area}"     Width="150"/>
                  <DataGridTextColumn Header="НАХОДКА" Binding="{Binding Title}"    Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ПРОЦЕССЫ ========== -->
        <TabItem Header="Процессы">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="06 — ПРОЦЕССЫ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Процессы" Style="{StaticResource H1}"/>
              <TextBlock Text="Что сейчас запущено, кем подписано и откуда взялось." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnProcRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <CheckBox x:Name="ChkOnlyRisky" Content="только подозрительные" IsChecked="True" Margin="12,0,0,0"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="ProcStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridProc">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="РИСК"    Binding="{Binding Risk}"      Width="66">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                  <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" SortMemberPath="Order" CellTemplate="{StaticResource SevCell}"/>
                  <DataGridTextColumn Header="ИМЯ"     Binding="{Binding Name}"      Width="200"/>
                  <DataGridTextColumn Header="PID"     Binding="{Binding Id}"        Width="70">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/><Setter Property="Foreground" Value="{StaticResource Muted}"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                  <DataGridTextColumn Header="ПОДПИСЬ" Binding="{Binding Signature}" Width="240"/>
                  <DataGridTextColumn Header="ПУТЬ"    Binding="{Binding Path}"      Width="*">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== РАСШИРЕНИЯ ========== -->
        <TabItem Header="Расширения">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="07 — РАСШИРЕНИЯ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Расширения браузеров" Style="{StaticResource H1}"/>
              <TextBlock Text="Расширение с правом читать все сайты видит ваши сессии так же, как вы." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnExtRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnExtVerify" Content="Перепроверить в магазине"/>
                  <Button x:Name="BtnExtStore" Content="Открыть в магазине" Style="{StaticResource Ghost}"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="ExtStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridExt">
                <DataGrid.Columns>
                  <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" SortMemberPath="Order" CellTemplate="{StaticResource SevCell}"/>
                  <DataGridTextColumn Header="БРАУЗЕР"  Binding="{Binding Browser}"  Width="95"/>
                  <DataGridTextColumn Header="НАЗВАНИЕ" Binding="{Binding Name}"     Width="240"/>
                  <DataGridTextColumn Header="ПРАВА"    Binding="{Binding Perms}"    Width="230"/>
                  <DataGridTextColumn Header="ПЕРЕПРОВЕРКА" Binding="{Binding Verify}" Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== АВТОЗАПУСК ========== -->
        <TabItem Header="Автозапуск">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="08 — АВТОЗАПУСК" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Автозапуск" Style="{StaticResource H1}"/>
              <TextBlock Text="Реестр, папки автозагрузки, задачи планировщика и службы." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                <Button x:Name="BtnAutoRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="AutoStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridAuto">
                <DataGrid.Columns>
                  <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" SortMemberPath="Order" CellTemplate="{StaticResource SevCell}"/>
                  <DataGridTextColumn Header="ТИП"     Binding="{Binding Kind}"     Width="150"/>
                  <DataGridTextColumn Header="ИМЯ"     Binding="{Binding Name}"     Width="250"/>
                  <DataGridTextColumn Header="КОМАНДА" Binding="{Binding Command}"  Width="*">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ЗАПУСКИ ========== -->
        <TabItem Header="Запуски">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="09 — ЗАПУСКИ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="История запусков" Style="{StaticResource H1}"/>
              <TextBlock Text="Что запускалось за последние часы и кто это запустил." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnRunRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <CheckBox x:Name="ChkRunOnlyBad" Content="только необычные" Margin="12,0,0,0"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="RunStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridRun">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="ВРЕМЯ"       Binding="{Binding TimeText}" Width="80">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/><Setter Property="Foreground" Value="{StaticResource Muted}"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                  <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96" SortMemberPath="Order" CellTemplate="{StaticResource SevCell}"/>
                  <DataGridTextColumn Header="ПРОГРАММА"   Binding="{Binding Name}"     Width="200"/>
                  <DataGridTextColumn Header="ЗАПУЩЕНА ИЗ" Binding="{Binding Parent}"   Width="170"/>
                  <DataGridTextColumn Header="КОМАНДА"     Binding="{Binding Command}"  Width="*">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== КАРАНТИН ========== -->
        <TabItem Header="Карантин">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="10 — КАРАНТИН" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Карантин" Style="{StaticResource H1}"/>
              <TextBlock Text="Спрятанные файлы. Запустить их нельзя, вернуть — можно, байт в байт." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnQuarRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnQuarRestore" Content="Восстановить"/>
                  <Button x:Name="BtnQuarDelete"  Content="Удалить насовсем" Style="{StaticResource Danger}"/>
                  <Button x:Name="BtnQuarFolder"  Content="Папка карантина" Style="{StaticResource Ghost}"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="QuarStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridQuar">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="В КАРАНТИНЕ С" Binding="{Binding QuarantinedText}" Width="150">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/><Setter Property="Foreground" Value="{StaticResource Muted}"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                  <DataGridTextColumn Header="ФАЙЛ"          Binding="{Binding Name}"           Width="220"/>
                  <DataGridTextColumn Header="ПРИЧИНА"       Binding="{Binding Reason}"         Width="240"/>
                  <DataGridTextColumn Header="БЫЛ ПО ПУТИ"   Binding="{Binding OriginalPath}"   Width="*">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ДОВЕРЕННЫЕ ========== -->
        <TabItem Header="Доверенные">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="11 — ДОВЕРЕННЫЕ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Доверенные" Style="{StaticResource H1}"/>
              <TextBlock Text="То, про что вы уже разобрались. Столбец «действует на» показывает, насколько широко." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
              <WrapPanel>
                  <Button x:Name="BtnTrustRefresh" Content="Обновить" Style="{StaticResource Primary}"/>
                  <Button x:Name="BtnTrustRevoke" Content="Снять доверие" Style="{StaticResource Danger}"/>
              </WrapPanel>
            </Border>
            <Border DockPanel.Dock="Bottom" Style="{StaticResource Readout}">
              <TextBlock x:Name="TrustStats" Text="" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis"/>
            </Border>
            <Border Style="{StaticResource GridBox}">
              <DataGrid x:Name="GridTrust">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="ОБЛАСТЬ"      Binding="{Binding Kind}"      Width="200"/>
                  <DataGridTextColumn Header="НАЗВАНИЕ"     Binding="{Binding Name}"      Width="200"/>
                  <DataGridTextColumn Header="ДЕЙСТВУЕТ НА" Binding="{Binding Covers}"    Width="*"/>
                  <DataGridTextColumn Header="ПРИЧИНА"      Binding="{Binding Note}"      Width="200"/>
                  <DataGridTextColumn Header="ДОБАВЛЕНО"    Binding="{Binding AddedText}" Width="140">
                    <DataGridTextColumn.ElementStyle>
                      <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="{StaticResource FontMono}"/><Setter Property="FontSize" Value="11.5"/><Setter Property="Foreground" Value="{StaticResource Muted}"/></Style>
                    </DataGridTextColumn.ElementStyle>
                  </DataGridTextColumn>
                </DataGrid.Columns>
              </DataGrid>
            </Border>
          </DockPanel>
        </TabItem>

        <!-- ========== ЖУРНАЛ ========== -->
        <TabItem Header="Журнал">
          <DockPanel Margin="32,26,32,24">
            <StackPanel DockPanel.Dock="Top" Style="{StaticResource PageHead}">
              <TextBlock Text="12 — ЖУРНАЛ" Style="{StaticResource Kicker}"/>
              <TextBlock Text="Журнал" Style="{StaticResource H1}"/>
              <TextBlock Text="Что программа делала и когда." Style="{StaticResource Sub}" Margin="0,6,0,0"/>
            </StackPanel>
            <Border DockPanel.Dock="Top" Style="{StaticResource ToolStrip}">
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
      <Border x:Name="Inspector" Grid.Column="2" Width="412" Background="{StaticResource NavBg}"
              BorderBrush="{StaticResource Line}" BorderThickness="1,0,0,0" Visibility="Collapsed">
        <DockPanel>
          <Grid DockPanel.Dock="Top" Margin="24,22,16,0">
            <StackPanel Margin="0,0,40,0">
              <TextBlock x:Name="InspKind" Text="ПОДРОБНОСТИ" Style="{StaticResource Kicker}" Margin="0"/>
              <TextBlock x:Name="InspTitle" Text="" Style="{StaticResource H2}" TextWrapping="Wrap" Margin="0,8,0,0"/>
            </StackPanel>
            <Button x:Name="BtnInspClose" Content="&#xE8BB;" Style="{StaticResource CaptionBtn}" Width="32" Height="32"
                    HorizontalAlignment="Right" VerticalAlignment="Top"/>
          </Grid>

          <Border DockPanel.Dock="Top" Height="1" Background="{StaticResource Line}" Margin="0,18,0,0"/>

          <StackPanel DockPanel.Dock="Top" Margin="24,16,24,0">
            <TextBlock Text="ЧТО МОЖНО СДЕЛАТЬ" Style="{StaticResource GroupLabel}"/>
            <WrapPanel>
              <Button x:Name="BtnTrust"    Content="Доверять" Style="{StaticResource Good}" Margin="0,0,7,7"/>
              <Button x:Name="BtnExplorer" Content="В проводнике" Margin="0,0,7,7"/>
              <Button x:Name="BtnWeb"      Content="Искать в сети" Margin="0,0,7,7"/>
              <Button x:Name="BtnVT"       Content="VirusTotal" Margin="0,0,7,7"/>
              <Button x:Name="BtnAsk"      Content="Спросить у ИИ" Margin="0,0,7,7"/>
              <Button x:Name="BtnCopy"     Content="Копировать" Style="{StaticResource Ghost}" Margin="0,0,7,7"/>
              <Button x:Name="BtnInspect"  Content="Разобрать" Margin="0,0,7,7"/>
            </WrapPanel>

            <!-- Исправления подбираются под находку и появляются здесь.
                 Пустой раздел не показываем: заголовок без кнопок —
                 обещание, которого программа не выполняет. -->
            <TextBlock x:Name="FixHead" Text="ЧТО ИСПРАВИТЬ" Style="{StaticResource GroupLabel}" Foreground="{StaticResource Ok}"
                       Margin="0,10,0,10" Visibility="Collapsed"/>
            <WrapPanel x:Name="FixPanel"/>

            <TextBlock Text="НЕОБРАТИМОЕ" Style="{StaticResource GroupLabel}" Foreground="{StaticResource Crit}" Margin="0,10,0,10"/>
            <WrapPanel>
              <Button x:Name="BtnKill"  Content="Завершить процесс" Margin="0,0,7,7"/>
              <Button x:Name="BtnQuar"  Content="В карантин" Margin="0,0,7,7"/>
              <Button x:Name="BtnNeutr" Content="Обезвредить" Style="{StaticResource Danger}" Margin="0,0,7,7"/>
            </WrapPanel>
          </StackPanel>

          <Border Margin="24,14,24,22">
            <TextBox x:Name="DetailBox" Style="{StaticResource Mono}" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
          </Border>
        </DockPanel>
      </Border>
    </Grid>

    <!-- ===================== СТРОКА СОСТОЯНИЯ ===================== -->
    <Border Grid.Row="2" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0" Padding="16,6">
      <Grid>
        <TextBlock x:Name="StatusText" Text="Готов" Style="{StaticResource Stat}"/>
        <ProgressBar x:Name="Progress" Width="190" Height="2" HorizontalAlignment="Right"
                     Visibility="Collapsed" IsIndeterminate="True"/>
      </Grid>
    </Border>
  </Grid>
  </Border>
</Window>
'@
