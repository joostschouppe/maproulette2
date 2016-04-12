package org.maproulette

import javax.inject.{Inject, Singleton}

import org.maproulette.actions.Actions
import play.api.Application

/**
  * @author cuthbertm
  */
@Singleton
class Config @Inject() (implicit val application:Application) {
  lazy val logoURL = application.configuration.getString("maproulette.logo") match {
    case Some(logo) => logo
    case None => "/assets/images/logo.png"// default to the Map Roulette Icon
  }

  lazy val superKey : Option[String] = application.configuration.getString("maproulette.super.key")

  lazy val superAccounts : List[String] = application.configuration.getString("maproulette.super.accounts") match {
    case Some(accs) => accs.split(",").toList
    case None => List.empty
  }

  def isDebugMode : Boolean = application.configuration.getBoolean(Config.KEY_DEBUG).getOrElse(false)

  def actionLevel : Int = application.configuration.getInt(Config.KEY_ACTION_LEVEL).getOrElse(Actions.ACTION_LEVEL_2)
}

object Config {
  val KEY_DEBUG = "maproulette.debug"
  val KEY_ACTION_LEVEL = "maproulette.action.level"
}