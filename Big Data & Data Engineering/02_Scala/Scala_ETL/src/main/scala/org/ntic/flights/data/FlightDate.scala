package org.ntic.flights.data
import com.sun.media.sound.InvalidFormatException

/**
 * This class is used to represent a date of a flight
 * @param day: Int
 * @param month: Int
 * @param year: Int
 */
case class FlightDate(day: Int,
                      month: Int,
                      year: Int) {
  override lazy val toString: String =
    f"$day%02d/$month%02d/$year%04d"
}

object FlightDate {
  /**
   * This function is used to convert a string to a FlightDate
   * @param date: String
   * @return FlightDate
   */
  def fromString(date: String): FlightDate = {
    val datePart = date.split(" ").headOption.getOrElse(
      throw new InvalidFormatException(s"$date tiene un formato inválido")
    )

    val parts: List[Int] =
      try {
        datePart.split("/").toList.map(_.toInt)
      } catch {
        case _: NumberFormatException =>
          throw new InvalidFormatException(s"$date tiene un formato inválido")
      }

    parts match {
      case List(month, day, year) =>
        assert(year >= 1987, s"Año inválido: $year")
        assert(month >= 1 && month <= 12, s"Mes inválido: $month")
        assert(day >= 1 && day <= 31, s"Día inválido: $day")

        FlightDate(day, month, year)

      case _ =>
        throw new InvalidFormatException(s"$date tiene un formato inválido")
    }
  }
}
