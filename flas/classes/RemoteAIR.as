﻿/*
* 
* Copyright (c) 2008-2009 Lu Aye Oo
* 
* @author Lu Aye Oo
* 
* http://code.google.com/p/flash-console/
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
package {


	import com.atticmedia.console.*;
	import com.atticmedia.console.view.*;

	import flash.display.*;
	import flash.events.*;
	import flash.filters.GlowFilter;

	public class RemoteAIR extends MovieClip {

		public function RemoteAIR() {
			
			stage.nativeWindow.alwaysInFront = true;
			
			C.start(this, "", 951);
			C.maxLines = 1000;
			C.visible = true;
			C.remote = true;
			C.commandLine = true;
			C.x = 10;
			C.y = 10;
			var console:Console = C.instance;
			
			var menu:DisplayObject = console.panels.mainPanel.getChildByName("menuField") as DisplayObject;
			menu.doubleClickEnabled = true;
			menu.addEventListener(MouseEvent.DOUBLE_CLICK, ondouble);
			console.panels.mainPanel.addEventListener(AbstractPanel.STARTED_DRAGGING, moveHandle);
			console.panels.mainPanel.addEventListener(AbstractPanel.STARTED_SCALING, scaleHandle);
			console.panels.mainPanel.addEventListener(AbstractPanel.CLOSED, closeHandle);
			console.filters = [new GlowFilter(0, 0.7, 5, 5)];
			//
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.addEventListener(Event.RESIZE, onStageResize);
			onStageResize();
		}
		private function ondouble(e:Event):void {
			if(stage.nativeWindow.displayState != NativeWindowDisplayState.MAXIMIZED){
				stage.nativeWindow.maximize();
			}else{
				stage.nativeWindow.restore();
			}
		}
		private function moveHandle(e:Event):void {
			stage.nativeWindow.startMove();
		}
		private function scaleHandle(e:Event):void {
			C.instance.panels.mainPanel.stopScaling();
			stage.nativeWindow.startResize(NativeWindowResize.BOTTOM_RIGHT);
		}
		private function closeHandle(e:Event):void {
			stage.nativeWindow.close();
		}
		private function onStageResize(e : Event = null):void {
			C.width = stage.stageWidth-20;
			C.height = stage.stageHeight-20;
			
			
		}
	}
}