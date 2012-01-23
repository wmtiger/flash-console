/*
 *
 * Copyright (c) 2008-2011 Lu Aye Oo
 *
 * @author 		Lu Aye Oo
 *
 * http://code.google.com/p/flash-console/
 * http://junkbyte.com
 *
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 * claim that you wrote the original software. If you use this software
 * in a product, an acknowledgment in the product documentation would be
 * appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 * misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 */
package com.junkbyte.console.view.mainPanel
{
	import com.junkbyte.console.ConsoleChannels;
	import com.junkbyte.console.core.ModuleTypeMatcher;
	import com.junkbyte.console.events.ConsoleEvent;
	import com.junkbyte.console.events.ConsoleLogEvent;
	import com.junkbyte.console.interfaces.ICommandLine;
	import com.junkbyte.console.interfaces.IConsoleModule;
	import com.junkbyte.console.interfaces.IKeyStates;
	import com.junkbyte.console.logging.ConsoleLogs;
	import com.junkbyte.console.modules.ConsoleModuleNames;
	import com.junkbyte.console.modules.userdata.IConsoleUserData;
	import com.junkbyte.console.utils.EscHTML;
	import com.junkbyte.console.utils.makeConsoleChannel;
	import com.junkbyte.console.view.ConsolePanel;
	import com.junkbyte.console.view.ConsoleScrollBar;
	import com.junkbyte.console.view.menus.LogPriorityMenu;
	import com.junkbyte.console.view.menus.SaveToClipboardMenu;
	import com.junkbyte.console.vos.ConsoleMenuItem;
	import com.junkbyte.console.vos.Log;
	
	import flash.display.Shape;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.ColorTransform;
	import flash.text.TextField;

	public class MainPanelLogs extends MainPanelSubArea
	{
		/**
		 * Remembers viewing filters such as channels and priority level over different sessions.
		 * <ul>
		 * <li>Must be set before starting console (before Cc.start / Cc.startOnStage)</li>
		 * <li>Requires sharedObject feature turned on</li>
		 * <li>Because console's SharedObject is shared across, your filtering settings will carry over to other flash projects</li>
		 * <li>You may want to set sharedObjectName to store project specificly</li>
		 * </ul>
		 */
		public var rememberFilterSettings:Boolean;
		public static const VIEWING_CHANNELS_CHANGED:String = "viewingChannelsChanged";
		public static const FILTER_PRIORITY_CHANGED:String = "filterPriorityChanged";
		private static const VIEWING_CH_HISTORY:String = "viewingChannels";
		private static const IGNORED_CH_HISTORY:String = "ignoredChannels";
		private static const PRIORITY_HISTORY:String = "priority";
		private var _userInfo:IConsoleUserData;
		private var _traceField:TextField;
		private var _bottomLine:Shape;
		private var _selectionStart:int;
		private var _selectionEnd:int;
		private var _filterText:String;
		private var _filterRegExp:RegExp;
		private var _scrollBar:ConsoleScrollBar;
		private var _needUpdateTrace:Boolean;
		private var _lockScrollUpdate:Boolean;
		private var _atBottom:Boolean = true;
		private var _viewingChannels:Array;
		private var _ignoredChannels:Array;
		private var _priority:uint;

		public function MainPanelLogs(parentPanel:ConsolePanel)
		{
			super(parentPanel);
			_viewingChannels = new Array();
			_ignoredChannels = new Array();

			_traceField = new TextField();
			_traceField.name = "traceField";
			_traceField.wordWrap = true;
			_traceField.multiline = true;
			_traceField.addEventListener(Event.SCROLL, onTraceScroll);
			//
			_bottomLine = new Shape();
			_bottomLine.name = "blinkLine";
			_bottomLine.alpha = 0.2;

			//
			_scrollBar = new ConsoleScrollBar();
			_scrollBar.addEventListener(Event.SCROLL, onScrollBarScroll);
			_scrollBar.addEventListener(ConsoleScrollBar.STARTED_SCROLLING, onScrollStarted);
			_scrollBar.addEventListener(ConsoleScrollBar.STOPPED_SCROLLING, onScrollEnded);

			_traceField.addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel, false, 0, true);

			addModuleRegisteryCallback(new ModuleTypeMatcher(IConsoleUserData), userInfoRegistered, userInfoUnregistered);
			addModuleRegisteryCallback(new ModuleTypeMatcher(ICommandLine), commandLineRegistered, commandLineUnregistered);
		}

		override protected function registeredToConsole():void
		{
			var mainPanel:MainPanel = console.mainPanel;

			_traceField.styleSheet = style.styleSheet;

			_scrollBar.setConsole(console);

			addChild(_traceField);
			addChild(_bottomLine);
			addChild(_scrollBar.sprite);

			console.addEventListener(ConsoleEvent.PAUSED, onConsolePaused);
			console.addEventListener(ConsoleEvent.RESUMED, onConsoleResumed);
			console.logger.logs.addEventListener(ConsoleLogEvent.ENTRIES_CHANGED, onTracesChanged);

			display.addEventListener(Event.ENTER_FRAME, onEnterFrame);

			super.registeredToConsole();

			addMenus();
		}

		override protected function unregisteredFromConsole():void
		{
			console.removeEventListener(ConsoleEvent.PAUSED, onConsolePaused);
			console.removeEventListener(ConsoleEvent.RESUMED, onConsoleResumed);
			console.logger.logs.removeEventListener(ConsoleLogEvent.ENTRIES_CHANGED, onTracesChanged);

			display.removeEventListener(Event.ENTER_FRAME, onEnterFrame);

			super.unregisteredFromConsole();
		}

		protected function addMenus():void
		{
			
			var logPriorityMenu:LogPriorityMenu = new LogPriorityMenu(this);
			logPriorityMenu.sortPriority = -80;
			mainPanel.menu.addMenu(logPriorityMenu);
			
			var saveMenu:SaveToClipboardMenu = new SaveToClipboardMenu();
			saveMenu.sortPriority = -50;
			
			mainPanel.menu.addMenu(saveMenu);
			
			var clearLogsMenu:ConsoleMenuItem = new ConsoleMenuItem("C", logger.logs.clear, null, "Clear log");
			clearLogsMenu.sortPriority = -80;
			mainPanel.menu.addMenu(clearLogsMenu);
		}

		private function onTracesChanged(e:Event):void
		{
			_needUpdateTrace = true;
		}

		protected function onConsolePaused(e:Event):void
		{
			if (_atBottom)
			{
				_atBottom = false;
				_updateTraces();
				_traceField.scrollV = _traceField.maxScrollV;
			}
		}

		protected function onConsoleResumed(e:Event):void
		{
			_atBottom = true;
			updateBottom();
		}

		override public function setArea(x:Number, y:Number, width:Number, height:Number):void
		{
			super.setArea(x, y, width, height);
			_lockScrollUpdate = true;
			_traceField.x = x;
			_traceField.y = y;
			_traceField.width = width - 5;
			_traceField.height = height;

			_bottomLine.graphics.clear();
			_bottomLine.graphics.lineStyle(1, style.controlColor);
			_bottomLine.graphics.moveTo(x + 10, -1);
			_bottomLine.graphics.lineTo(x + width - 10, -1);
			_bottomLine.y = y + height;
			//
			_scrollBar.x = x + width;
			_scrollBar.y = y;
			_scrollBar.setBarSize(5, height);
			//
			_atBottom = true;
			_needUpdateTrace = true;
			_lockScrollUpdate = false;
		}

		protected function userInfoRegistered(module:IConsoleUserData):void
		{
			_userInfo = module;
			//
			if (rememberFilterSettings && _userInfo.data[VIEWING_CH_HISTORY] is Array)
			{
				_viewingChannels = _userInfo.data[VIEWING_CH_HISTORY];
			}
			else
			{
				_userInfo.data[VIEWING_CH_HISTORY] = _viewingChannels = new Array();
			}
			if (rememberFilterSettings && _userInfo.data[IGNORED_CH_HISTORY] is Array)
			{
				_ignoredChannels = _userInfo.data[IGNORED_CH_HISTORY];
			}
			if (_viewingChannels.length > 0 || _ignoredChannels == null)
			{
				_userInfo.data[IGNORED_CH_HISTORY] = _ignoredChannels = new Array();
			}
			if (rememberFilterSettings && _userInfo.data[PRIORITY_HISTORY] is uint)
			{
				_priority = _userInfo.data[PRIORITY_HISTORY];
			}
		}

		protected function userInfoUnregistered(module:IConsoleModule):void
		{
			_userInfo = null;
		}

		protected function commandLineRegistered(module:ICommandLine):void
		{
			module.setInternalSlashCommand("filter", setFilterText, "Filter console logs to matching string. When done, click on the * (global channel) at top.", true);
			module.setInternalSlashCommand("filterexp", setFilterRegExp, "Filter console logs to matching regular expression", true);
		}

		protected function commandLineUnregistered(module:ICommandLine):void
		{
			module.setInternalSlashCommand("filter", null);
			module.setInternalSlashCommand("filterexp", null);
		}

		protected function onEnterFrame(event:Event):void
		{
			if (_bottomLine.alpha > 0)
			{
				_bottomLine.alpha -= 0.25;
			}
			if (_needUpdateTrace)
			{
				_bottomLine.alpha = 1;
				_needUpdateTrace = false;
				_updateTraces(true);
			}
		}

		public function getChannelsLink(limited:Boolean = false):String
		{
			var str:String = "<chs>";
			var channels:Array = console.logger.logs.getChannels();
			var len:int = channels.length;
			if (limited && len > style.maxChannelsInMenu)
			{
				len = style.maxChannelsInMenu;
			}
			var filtering:Boolean = _viewingChannels.length > 0 || _ignoredChannels.length > 0;
			for (var i:int = 0; i < len; i++)
			{
				var channel:String = channels[i];
				var channelTxt:String = ((!filtering && i == 0) || (filtering && i != 0 && chShouldShow(channel))) ? "<ch><b>" + channel + "</b></ch>" : channel;
				str += "<a href=\"event:channel_" + channel + "\">[" + channelTxt + "]</a> ";
			}
			if (limited)
			{
				str += "<ch><a href=\"event:channels\"><b>" + (channels.length > len ? "..." : "") + "</b>^^ </a></ch>";
			}
			str += "</chs> ";
			return str;
		}

		public function requestLogin(on:Boolean = true):void
		{
			if (on)
			{
				_traceField.transform.colorTransform = new ColorTransform(0.7, 0.7, 0.7);
			}
			else
			{
				_traceField.transform.colorTransform = new ColorTransform();
			}
		}

		public function onChannelPressed(chn:String):void
		{
			var current:Array;

			var keyStates:IKeyStates = modules.getModuleByName(ConsoleModuleNames.KEY_STATES) as IKeyStates;

			if (keyStates != null && keyStates.ctrlKeyDown && chn != ConsoleChannels.GLOBAL)
			{
				current = toggleCHList(_ignoredChannels, chn);
				setIgnoredChannels.apply(this, current);
			}
			else if (keyStates != null && keyStates.shiftKeyDown && chn != ConsoleChannels.GLOBAL && _viewingChannels[0] != ConsoleChannels.INSPECTING)
			{
				current = toggleCHList(_viewingChannels, chn);
				setViewingChannels.apply(this, current);
			}
			else
			{
				console.mainPanel.setViewingChannels(chn);
			}
		}

		private function toggleCHList(current:Array, chn:String):Array
		{
			current = current.concat();
			var ind:int = current.indexOf(chn);
			if (ind >= 0)
			{
				current.splice(ind, 1);
				if (current.length == 0)
				{
					current.push(ConsoleChannels.GLOBAL);
				}
			}
			else
			{
				current.push(chn);
			}
			return current;
		}

		public function set priority(p:uint):void
		{
			_priority = p;
			// central.so[PRIORITY_HISTORY] = _priority;
			updateToBottom();
			dispatchEvent(new Event(FILTER_PRIORITY_CHANGED));
		}

		public function get priority():uint
		{
			return _priority;
		}

		//
		public function incPriority(down:Boolean):void
		{
			var top:uint = 10;
			var bottom:uint;
			var line:Log = console.logger.logs.last;
			var p:int = _priority;
			_priority = 0;
			var i:uint = 32000;
			// just for crash safety, it wont look more than 32000 lines.
			while (line && i > 0)
			{
				i--;
				if (lineShouldShow(line))
				{
					if (line.priority > p && top > line.priority)
					{
						top = line.priority;
					}
					if (line.priority < p && bottom < line.priority)
					{
						bottom = line.priority;
					}
				}
				line = line.prev;
			}
			if (down)
			{
				if (bottom == p)
				{
					p = 10;
				}
				else
				{
					p = bottom;
				}
			}
			else
			{
				if (top == p)
				{
					p = 0;
				}
				else
				{
					p = top;
				}
			}
			priority = p;
		}

		public function updateToBottom():void
		{
			_atBottom = true;
			_needUpdateTrace = true;
		}

		private function _updateTraces(onlyBottom:Boolean = false):void
		{
			if (_atBottom)
			{
				updateBottom();
			}
			else if (!onlyBottom)
			{
				updateFull();
			}
			if (_selectionStart != _selectionEnd)
			{
				if (_atBottom)
				{
					_traceField.setSelection(_traceField.text.length - _selectionStart, _traceField.text.length - _selectionEnd);
				}
				else
				{
					_traceField.setSelection(_traceField.text.length - _selectionEnd, _traceField.text.length - _selectionStart);
				}
				_selectionEnd = -1;
				_selectionStart = -1;
			}
		}

		private function updateFull():void
		{
			var str:String = "";
			var line:Log = console.logger.logs.last;
			var showch:Boolean = _viewingChannels.length != 1;
			while (line)
			{
				if (lineShouldShow(line))
				{
					str = makeLine(line, showch) + str;
				}
				line = line.prev;
			}
			_lockScrollUpdate = true;
			_traceField.htmlText = str;
			_lockScrollUpdate = false;
			updateScroller();
		}

		private function updateBottom():void
		{
			var lines:Array = new Array();
			var linesLeft:int = Math.round(_traceField.height / style.traceFontSize);
			var maxchars:int = Math.round(_traceField.width * 5 / style.traceFontSize);

			var line:Log = console.logger.logs.last;
			var showch:Boolean = _viewingChannels.length != 1;
			while (line)
			{
				if (lineShouldShow(line))
				{
					lines.push(makeLine(line, showch));
					var numlines:int = Math.ceil(line.text.length / maxchars);
					linesLeft -= numlines;
					if (linesLeft <= 0)
					{
						break;
					}
				}
				line = line.prev;
			}
			_lockScrollUpdate = true;
			_traceField.htmlText = lines.reverse().join("");
			_traceField.scrollV = _traceField.maxScrollV;
			_lockScrollUpdate = false;
			updateScroller();
		}

		public function lineShouldShow(line:Log):Boolean
		{
			return ((chShouldShow(line.channel) || (_filterText && _viewingChannels.indexOf(ConsoleChannels.FILTERING) >= 0 && line.text.toLowerCase().indexOf(_filterText) >= 0) || (_filterRegExp && _viewingChannels.indexOf(ConsoleChannels.FILTERING) >= 0 && line.text.search(_filterRegExp) >= 0)) && (_priority == 0 || line.priority >= _priority));
		}

		private function chShouldShow(ch:String):Boolean
		{
			return ((_viewingChannels.length == 0 || _viewingChannels.indexOf(ch) >= 0) && (_ignoredChannels.length == 0 || _ignoredChannels.indexOf(ch) < 0));
		}

		public function get reportChannel():String
		{
			return _viewingChannels.length == 1 ? _viewingChannels[0] : ConsoleChannels.CONSOLE;
		}

		public function setViewingChannels(... channels:Array):void
		{
			var a:Array = new Array();
			for each (var item:Object in channels)
			{
				a.push(makeConsoleChannel(item));
			}

			/*
			TODO
			if(_viewingChannels[0] == Logs.INSPECTING_CHANNEL && (!a || a[0] != _viewingChannels[0])){
			central.refs.exitFocus();
			}*/

			_ignoredChannels.splice(0);
			_viewingChannels.splice(0);
			if (a.indexOf(ConsoleChannels.GLOBAL) < 0 && a.indexOf(null) < 0)
			{
				for each (var ch:String in a)
				{
					_viewingChannels.push(ch);
				}
			}
			updateToBottom();
			announceChannelInterestChanged();
		}

		private function announceChannelInterestChanged():void
		{
			dispatchEvent(new Event(VIEWING_CHANNELS_CHANGED));
		}

		public function setIgnoredChannels(... channels:Array):void
		{
			var a:Array = new Array();
			for each (var item:Object in channels)
			{
				a.push(makeConsoleChannel(item));
			}

			/*
			TODO
			if(_viewingChannels[0] == Logs.INSPECTING_CHANNEL){
			central.refs.exitFocus();
			}*/

			_ignoredChannels.splice(0);
			_viewingChannels.splice(0);
			if (a.indexOf(ConsoleChannels.GLOBAL) < 0 && a.indexOf(null) < 0)
			{
				for each (var ch:String in a)
				{
					_ignoredChannels.push(ch);
				}
			}
			updateToBottom();
		}

		private function setFilterText(str:String = ""):void
		{
			if (str)
			{
				_filterRegExp = null;
				_filterText = EscHTML(str.toLowerCase());
				startFilter();
			}
			else
			{
				endFilter();
			}
		}

		private function setFilterRegExp(expstr:String = ""):void
		{
			if (expstr)
			{
				_filterText = null;
				_filterRegExp = new RegExp(EscHTML(expstr), "gi");
				startFilter();
			}
			else
			{
				endFilter();
			}
		}

		private function startFilter():void
		{
			logger.logs.clear(ConsoleChannels.FILTERING);
			logger.logs.addChannel(ConsoleChannels.FILTERING);
			setViewingChannels(ConsoleChannels.FILTERING);
		}

		private function endFilter():void
		{
			_filterRegExp = null;
			_filterText = null;
			if (_viewingChannels.length == 1 && _viewingChannels[0] == ConsoleChannels.FILTERING)
			{
				setViewingChannels(ConsoleChannels.GLOBAL);
			}
		}

		private function makeLine(line:Log, showch:Boolean):String
		{
			var str:String = "";
			var txt:String = line.text;
			if (showch && line.channel != ConsoleChannels.DEFAULT)
			{
				txt = "[<a href=\"event:channel_" + line.channel + "\">" + line.channel + "</a>] " + txt;
			}
			var index:int;
			if (_filterRegExp)
			{
				// need to look into every match to make sure there no half way HTML tags and not inside the HTML tags it self in the match.
				_filterRegExp.lastIndex = 0;
				var result:Object = _filterRegExp.exec(txt);
				while (result != null)
				{
					index = result.index;
					var match:String = result[0];
					if (match.search("<|>") >= 0)
					{
						_filterRegExp.lastIndex -= match.length - match.search("<|>");
					}
					else if (txt.lastIndexOf("<", index) <= txt.lastIndexOf(">", index))
					{
						txt = txt.substring(0, index) + "<u>" + txt.substring(index, index + match.length) + "</u>" + txt.substring(index + match.length);
						_filterRegExp.lastIndex += 7;
							// need to add to satisfy the fact that we added <u> and </u>
					}
					result = _filterRegExp.exec(txt);
				}
			}
			else if (_filterText)
			{
				// could have been simple if txt.replace replaces every match.
				var lowercase:String = txt.toLowerCase();
				index = lowercase.lastIndexOf(_filterText);
				while (index >= 0)
				{
					txt = txt.substring(0, index) + "<u>" + txt.substring(index, index + _filterText.length) + "</u>" + txt.substring(index + _filterText.length);
					index = lowercase.lastIndexOf(_filterText, index - 2);
				}
			}
			var ptag:String = "p" + line.priority;
			str += "<p><" + ptag + ">" + txt + "</" + ptag + "></p>";
			return str;
		}

		private function onTraceScroll(e:Event = null):void
		{
			var keyStates:IKeyStates = modules.getModuleByName(ConsoleModuleNames.KEY_STATES) as IKeyStates;

			if (_lockScrollUpdate || (keyStates != null && keyStates.shiftKeyDown))
			{
				return;
			}
			var atbottom:Boolean = _traceField.scrollV >= _traceField.maxScrollV;
			if (!console.paused && _atBottom != atbottom)
			{
				var diff:int = _traceField.maxScrollV - _traceField.scrollV;
				_selectionStart = _traceField.text.length - _traceField.selectionBeginIndex;
				_selectionEnd = _traceField.text.length - _traceField.selectionEndIndex;
				_atBottom = atbottom;
				_updateTraces();
				_traceField.scrollV = _traceField.maxScrollV - diff;
			}
			updateScroller();
		}

		private function updateScroller():void
		{
			_scrollBar.maxScroll = _traceField.maxScrollV - 1;
			if (_atBottom)
			{
				_scrollBar.scroll = _scrollBar.maxScroll;
			}
			else
			{
				_scrollBar.scroll = _traceField.scrollV - 1;
			}
		}

		private function onScrollBarScroll(e:Event):void
		{
			_lockScrollUpdate = true;
			_traceField.scrollV = _scrollBar.scroll + 1;
			_lockScrollUpdate = false;
		}

		private function onScrollStarted(e:Event):void
		{
			if (!console.paused && _atBottom)
			{
				_atBottom = false;
				var p:Number = _scrollBar.scrollPercent;
				_updateTraces();
				_scrollBar.scrollPercent = p;
			}
		}
		
		private function onScrollEnded(e:Event):void
		{
			onTraceScroll();
		}

		private function onMouseWheel(e:MouseEvent):void
		{
			var keyStates:IKeyStates = modules.getModuleByName(ConsoleModuleNames.KEY_STATES) as IKeyStates;

			if (keyStates != null && keyStates.shiftKeyDown)
			{
				var s:int = style.traceFontSize + (e.delta > 0 ? 1 : -1);
				if (s >= 8 && s <= 20)
				{
					style.traceFontSize = s;
					style.updateStyleSheet();
					updateToBottom();
					e.stopPropagation();
				}
			}
		}
	}
}
