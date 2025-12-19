package org.ntic.flights.data

import com.sun.media.sound.InvalidFormatException
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.must.Matchers
import org.scalatest.matchers.should.Matchers.convertToAnyShouldWrapper

class FlightDateTest extends AnyFlatSpec with Matchers {
  "A FlightDate" should "be correctly initialized from string" in {
    val dateStr = "7/1/2023 12:00:00 AM"
    val expected = FlightDate(day = 1, month = 7, year = 2023)
    val result = FlightDate.fromString(dateStr)
    result shouldEqual expected
  }

  "A FlightDate" should "raise an Exception because of wrong string format" in {
    val dateStr = "7/1/2023/3 12:00:00 AM"
    an [InvalidFormatException] should be thrownBy FlightDate.fromString(dateStr)
  }

  "A FlightDate" should "print its value in corrected format: DD/MM/YYYY" in {
    val dateStr = "7/1/2023 12:00:00 AM" // formato recibido desde la fuente de datos
    val flightDate = FlightDate.fromString(dateStr)
    val expected = "01/07/2023" // formato esperado
    val result = flightDate.toString
    result shouldEqual expected
  }

}
