package org.ntic.flights

import org.ntic.flights.data.{Flight, FlightsFileReport, Row}

import scala.util.Try

object FlightsLoaderApp extends App {

  val fileLines: Seq[String] = FileUtils.getLinesFromFile(FlightsLoaderConfig.filePath)
  val rows: Seq[Try[Row]] = FileUtils.loadFromFileLines(fileLines)
  val flightReport: FlightsFileReport = FlightsFileReport.fromRows(rows)
  val flights: Seq[Flight] = flightReport.validRows.map(Flight.fromRow)

  FlightsLoaderConfig.filteredOrigin.foreach { originCode =>

    // Vuelos cuyo origen coincide con el código configurado
    val filteredFlights: Seq[Flight] =
      flights.filter(_.origin.code == originCode)

    // Vuelos retrasados, ordenados por hora real de llegada
    val delayedFlights: Seq[Flight] =
      filteredFlights.filter(_.isDelayed).sorted

    // Vuelos no retrasados, ordenados
    val notDelayedFlights: Seq[Flight] =
      filteredFlights.filterNot(_.isDelayed).sorted

    // Paths de salida
    val delayedFlightsObj: String =
      s"${FlightsLoaderConfig.outputDir}/${originCode}_delayed.obj"

    val flightsObj: String =
      s"${FlightsLoaderConfig.outputDir}/${originCode}.obj"

    // Escritura de los .obj
    FileUtils.writeFile(delayedFlights, delayedFlightsObj)
    FileUtils.writeFile(notDelayedFlights, flightsObj)
  }
  println(flightReport)
}
