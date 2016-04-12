package org.maproulette.models

import play.api.data._
import play.api.data.Forms._
import com.google.inject.Inject
import org.maproulette.actions.Actions
import org.maproulette.models.dal.ProjectDAL
import play.api.libs.json.{Json, Reads, Writes}

/**
  * The Challenge object is a child of the project object and contains Task objects as it's children.
  * It would be consider a specific problem set under a projects domain. It contains the following
  * parameters:
  *
  * id - The id assigned by the database
  * name - The name of the challenge
  * identifier - A unique identifier for the Challenge TODO: this should be removed. No real reason to keep this anymore
  * parent - The id of the project that is the parent of this challenge
  * difficulty - How difficult this challenge is consider, EASY, NORMAL or EXPERT
  * description - a brief description of the challenge
  * blurb - a quick blurb describing the problem
  * instruction - a detailed set of instructions on generally how the tasks within the challenge should be fixed
  *
  * @author cuthbertm
  */
case class Challenge(override val id: Long,
                     override val name: String,
                     override val identifier:Option[String]=None,
                     override val description:Option[String]=None,
                     parent:Long,
                     instruction:String,
                     difficulty:Option[Int]=None,
                     blurb:Option[String]=None,
                     enabled:Boolean=true,
                     challengeType:Int=Actions.ITEM_TYPE_CHALLENGE) extends ChildObject[Long, Project] {

  @Inject val projectDAL:ProjectDAL = null

  override def getParent = projectDAL.retrieveById(parent).get
}

object Challenge {
  implicit val challengeWrites: Writes[Challenge] = Json.writes[Challenge]
  implicit val challengeReads: Reads[Challenge] = Json.reads[Challenge]

  val challengeForm = Form(
    mapping(
      "id" -> default(longNumber, -1L),
      "name" -> nonEmptyText,
      "identifier" -> optional(text),
      "description" -> optional(text),
      "parent" -> longNumber,
      "instruction" -> nonEmptyText,
      "difficulty" -> optional(number(min = 1, max = 3)),
      "blurb" -> optional(text),
      "enabled" -> boolean,
      "challengeType" -> default(number, Actions.ITEM_TYPE_CHALLENGE)
    )(Challenge.apply)(Challenge.unapply)
  )

  def emptyChallenge(parentId:Long) = Challenge(-1, "", None, None, parentId, "")

  val DIFFICULTY_EASY = 1
  val DIFFICULTY_NORMAL = 2
  val DIFFICULTY_EXPERT = 3
}