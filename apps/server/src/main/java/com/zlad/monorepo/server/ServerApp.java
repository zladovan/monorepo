package com.zlad.monorepo.server;

import com.zlad.monorepo.common.Commons;
import com.zlad.monorepo.logging.Logger;

public class ServerApp {

	public static void main(String[] args) {
		Logger.info("Hi, I will be the server when I will grow up.");
		Logger.info("For now I know our commons: " + Commons.tellMeWhoWeAre());
	}
}
