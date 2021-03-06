// Copyright (C) 2016 MapRoulette contributors (see CONTRIBUTORS.md).
// Licensed under the Apache License, Version 2.0 (see LICENSE).
package org.maproulette.jobs

import javax.inject.{Inject, Named}

import akka.actor.{ActorRef, ActorSystem}
import org.maproulette.Config
import play.api.{Application, Logger}

import scala.concurrent.ExecutionContext
import scala.concurrent.duration._

/**
  * @author cuthbertm
  * @author davis_20
  */
class Scheduler @Inject() (val system: ActorSystem,
                           @Named("scheduler-actor") val schedulerActor:ActorRef,
                           val config:Config)
                          (implicit application:Application, ec:ExecutionContext) {

  schedule("cleanLocks", "Cleaning locks", 1.minute, Config.KEY_SCHEDULER_CLEAN_LOCKS_INTERVAL)
  schedule("runChallengeSchedules", "Running challenge Schedules", 1.minute, Config.KEY_SCHEDULER_RUN_CHALLENGE_SCHEDULES_INTERVAL)
  schedule("updateLocations", "Updating locations", 1.minute, Config.KEY_SCHEDULER_UPDATE_LOCATIONS_INTERVAL)
  schedule("cleanOldTasks", "Cleaning old tasks", 1.minute, Config.KEY_SCHEDULER_CLEAN_TASKS_INTERVAL)

  /**
    * Conditionally schedules message event when configured with a valid duration
    *
    * @param name The message name sent to the SchedulerActor
    * @param action The action this job is performing for logging
    * @param initialDelay FiniteDuration until the initial message is sent
    * @param intervalKey Configuration key that, when set, will enable periodic scheduled messages
    */
  def schedule(name:String, action:String, initialDelay:FiniteDuration, intervalKey:String):Unit = {
    config.withFiniteDuration(intervalKey) {
      interval =>
        this.system.scheduler.schedule(initialDelay, interval, this.schedulerActor, name)
        Logger.info(s"$action every $interval")
    }
  }
}
