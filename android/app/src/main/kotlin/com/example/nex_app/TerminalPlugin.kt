package com.example.nex_app

import android.content.Context
import android.os.Environment
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.Executors

class TerminalPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "nex_app/terminal")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "runCommand" -> {
                val command = call.argument<String>("command") ?: ""
                val workingDirectory = call.argument<String>("workingDirectory") ?: ""
                runCommand(command, workingDirectory, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun runCommand(command: String, workingDirectory: String, result: MethodChannel.Result) {
        val executor = Executors.newSingleThreadExecutor()
        executor.execute {
            try {
                val shell = if (command.startsWith("cd ")) {
                    "sh"
                } else {
                    "sh"
                }
                val processBuilder = ProcessBuilder(listOf(shell, "-c", command))
                val env = processBuilder.environment()
                env["PATH"] = env["PATH"] + ":/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin:/vendor/bin"
                if (workingDirectory.isNotBlank()) {
                    processBuilder.directory(java.io.File(workingDirectory))
                } else {
                    processBuilder.directory(Environment.getExternalStorageDirectory())
                }

                val process = processBuilder.start()
                val outputReader = BufferedReader(InputStreamReader(process.inputStream))
                val errorReader = BufferedReader(InputStreamReader(process.errorStream))
                val output = StringBuilder()
                var line: String?
                while (outputReader.readLine().also { line = it } != null) {
                    output.append(line).append('\n')
                }
                while (errorReader.readLine().also { line = it } != null) {
                    output.append(line).append('\n')
                }

                val exitCode = process.waitFor()
                executor.shutdown()
                result.success(mapOf("output" to output.toString(), "exitCode" to exitCode))
            } catch (e: Exception) {
                executor.shutdown()
                result.error("COMMAND_ERROR", e.message, e.toString())
            }
        }
    }
}
