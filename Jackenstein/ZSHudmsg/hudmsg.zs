// ZScript HudMessage by Agent_Ash
// (c) Agent_Ash aka Jekyll Grim Payne aka jekyllgrim

class JGP_HudMessageHandler : StaticEventHandler
{
	array < JGP_HudMessage > hudmessages;

	override void WorldTick()
	{
		for (int i = 0; i < hudmessages.Size(); i++)
		{
			let hmsg = hudmessages[i];
			if (hmsg)
			{
				hmsg.Ticker();
			}
			else
			{
				hudmessages.Delete(i);
			}
		}
	}

	override void InterfaceProcess(ConsoleEvent e)
	{
		// test code (type "interfaceevent testhudmsg" in console to test):
		if (e.name == "testhudmsg")
		{
			JGP_HudMessage.CreateUI("$GOTSHOTGUN", id: 1, fontname: 'BigUpper', fontcolor: Font.CR_Green, alignment: JGP_HudMessage.ALIGN_CENTER, fadeinTime: 0, typeTime: 2, holdtime: 35, fadeOutTime: 50, scale: (0.5, 0.5));
		}
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		// test code (type "netevent testhudmsg" in console to test):
		if (e.name == "testhudmsg")
		{
			JGP_HudMessage.Create("$GOTSHOTGUN", id: 1, fontname: 'BigUpper', fontcolor: Font.CR_Green, alignment: JGP_HudMessage.ALIGN_CENTER, fadeinTime: 0, typeTime: 2, holdtime: 35, fadeOutTime: 50, scale: (0.5, 0.5), playerNumber: e.Player);
		}

		if (e.name.IndexOf("createzshudmessage") >= 0)
		{
			array <string> msg;
			e.name.Split(msg,":");
			if (msg.Size() == 14)
			{
				JGP_HudMessage.Create(
					msg[1], //text
					id: msg[2].ToInt(10),
					fontname: msg[3], 
					fontcolor: msg[4].ToInt(10), 
					pos: (msg[5].ToDouble(), msg[6].ToDouble()), 
					alignment: msg[7].ToInt(10), 
					fadeInTime: msg[8].ToInt(10), 
					typeTime: msg[9].ToInt(10), 
					holdTime: msg[10].ToInt(10), 
					fadeOutTime: msg[11].ToInt(10), 
					scale: (msg[12].ToDouble(), msg[13].ToDouble()),
					playerNumber: e.Player
				);
			}
			else
			{
				console.printf("\cgHudMessage.CreateUI error. Expected \cd14\cg arguments, got \cd%d", msg.Size());
			}
		}
	}

	override void RenderUnderlay(RenderEvent e)
	{
		for (int i = 0; i < hudmessages.Size(); i++)
		{
			let hmsg = hudmessages[i];
			if (hmsg && (hmsg.playernumber < 0 || hmsg.playerNumber == consoleplayer))
			{
				//console.printf("Drawing message '%s' at %.1f, %.1f | alpha %.2f", text, pos.x, pos.y, alpha);
				Screen.DrawText(
					hmsg.msgFont, hmsg.fontColor,
					hmsg.pos.x, hmsg.pos.y,
					hmsg.text,
					DTA_VirtualWidth, 320,
					DTA_VirtualHeight, 200,
					DTA_ScaleX, hmsg.scale.x,
					DTA_ScaleY, hmsg.scale.y,
					DTA_Alpha, hmsg.alpha,
					DTA_FulLScreenScale, FSMode_ScaleToFit43
				);
			}
		}
	}
}

class JGP_HudMessage play
{
	int playerNumber;

	protected uint id;
	protected string fulltext;
	protected uint characters;
	protected uint curChar;

	string text;
	Font msgFont;
	vector2 pos;
	int fontColor;
	vector2 scale;
	double alpha;

	protected uint duration;
	protected uint typeTime;
	protected uint totalTypeTime;
	protected uint fadeInTime;
	protected uint totalfadeInTime;
	protected uint fadeOutTime;
	protected uint totalfadeOutTime;
	protected vector2 virtualRes;

	enum ETextAlignment
	{
		ALIGN_CENTER,
		ALIGN_LEFT,
		ALIGN_RIGHT
	}

	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max, bool clampIt = false) {
		double d = (val - source_min) * (out_max - out_min) / (source_max - source_min) + out_min;
		if (clampit) {
			double truemax = out_max > out_min ? out_max : out_min;
			double truemin = out_max > out_min ? out_min : out_max;
			d = Clamp(d, truemin, truemax);
		}
		return d;
	}

	static ui void CreateUI(string text, uint id = 0, name fontname = 'NewSmallFont', int fontColor = Font.CR_Red, vector2 pos = (160, 50), int alignment = ALIGN_LEFT, uint fadeInTime = 0, uint typeTime = 0, uint holdTime = 35, uint fadeOutTime = 0, vector2 scale = (1,1))
	{
		EventHandler.SendNetworkEvent(
			String.Format(
				"createzshudmessage:%s:%d:%s:%d:%f:%f:%d:%d:%d:%d:%d:%f:%f",
				text, id, fontname, fontcolor, pos.x, pos.y, alignment, fadeinTime, typeTime, holdTime, fadeOutTime, scale.x, scale.y
			)
		);
	}

	static JGP_HudMessage Create(string text, uint id = 0, name fontname = 'NewSmallFont', int fontColor = Font.CR_Red, vector2 pos = (160, 50), int alignment = ALIGN_LEFT, uint fadeInTime = 0, uint typeTime = 0, uint holdTime = 35, uint fadeOutTime = 0, vector2 scale = (1,1), int playerNumber = -1)
	{
		let hmsg = JGP_HudMessage(New("JGP_HudMessage"));
		let handler = JGP_HudMessageHandler(StaticEventHandler.Find("JGP_HudMessageHandler"));
		if (!handler)
		{
			ThrowAbortException("HUDMessage handler not found");
			return null;
		}
		if (hmsg)
		{
			hmsg.playerNumber = Clamp(playerNumber, -1, MAXPLAYERS);
			hmsg.scale = scale;
			// id:
			hmsg.id = id;
			if (id > 0)
			{
				for (int i = 0; i < handler.hudmessages.Size(); i++)
				{
					let othermsg = handler.hudmessages[i];
					if (othermsg && othermsg.id == id)
					{
						othermsg.Purge();
						break;
					}
				}
			}
			// text:
			hmsg.fulltext = StringTable.Localize(text);
			hmsg.characters = hmsg.fulltext.Length();
			hmsg.msgFont = Font.FindFont(fontname);
			hmsg.fontColor = fontColor;
			if (typeTime == 0)
			{
				hmsg.text = hmsg.fulltext;
			}
			// pos:
			double textwidth = hmsg.msgFont.StringWidth(hmsg.fulltext) * scale.x;
			switch (alignment)
			{
			case ALIGN_CENTER:
				pos.x -= textwidth * 0.5;
				break;
			case ALIGN_RIGHT:
				pos.x -= textwidth;
				break;
			}
			hmsg.pos = pos;
			// times:
			hmsg.duration = holdTime;
			hmsg.totalFadeInTime = fadeInTime;
			hmsg.totalFadeOutTime = fadeOutTime;
			hmsg.typeTime = typeTime;
			hmsg.totalTypeTime = typeTime * hmsg.characters;
			hmsg.duration += max(fadeInTime, hmsg.totalTypeTime);
			if (fadeInTime <= 0)
			{
				hmsg.alpha = 1;
			}
			handler.hudmessages.Push(hmsg);
		}
		return hmsg;
	}

//	clearscope string, vector2, double, Font, int GetText()
//	{
//		return text, pos, alpha, msgFont, fontcolor;
//	}

	uint GetID()
	{
		return id;
	}

	void Purge()
	{
		fulltext = "";
	}

	void Ticker()
	{
		if (!fulltext)
		{
			Destroy();
			return;
		}
		
		// tic down duration:
		if (duration > 0)
		{
			duration--;
		}
		// if duration has run out, tic down fade-out time
		// and reduce alpha:
		else if (totalFadeOutTime > 0 && fadeOutTime < totalFadeOutTime)
		{
			alpha = LinearMap(fadeOutTime, 0, totalFadeOutTime, 1., 0.);
			fadeOutTime++;
		}
		// if both have run out, destroy this message:
		else
		{
			Destroy();
			return;
		}

		// fade-in time is handled separately because fade-in
		// and typing may happen at the same time, and the bigger 
		// of the two values (totalTypeTime or fadeInTime) is
		// automatically added to duration on initialization:
		if (totalFadeInTime > 0 && fadeInTime < totalFadeInTime)
		{
			alpha = LinearMap(fadeInTime, 0, totalFadeInTime, 0., 1.);
			fadeInTime++;
		}

		// type the next character:
		if (totalTypeTime > 0 && curChar < characters)
		{
			if (totalTypeTime % typeTime == 0)
			{
				int codepoint, nextpos;
				[codepoint, nextpos] = fulltext.GetNextCodePoint(curChar);
				curChar = nextpos;
				//curChar++;
				//text = fulltext.Left(curChar);
				text.AppendCharacter(codepoint);
			}
			totalTypeTime--;
		}
	}
}