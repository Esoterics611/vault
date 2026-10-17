/**
 * Logger Utility
 * Provides Winston-based logging for the PRE Proxy service
 */

const winston = require('winston');

const logLevel = process.env.LOG_LEVEL || 'info';
const logFormat = process.env.LOG_FORMAT || 'json';

// Define log format
const formats = {
  json: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  pretty: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
      let msg = `${timestamp} [${level.toUpperCase()}]: ${message}`;
      if (Object.keys(meta).length > 0) {
        msg += ` ${JSON.stringify(meta)}`;
      }
      return msg;
    })
  )
};

// Create logger instance
const logger = winston.createLogger({
  level: logLevel,
  format: formats[logFormat] || formats.json,
  defaultMeta: { service: 'pre-proxy' },
  transports: [
    // Console output
    new winston.transports.Console({
      format: logFormat === 'pretty'
        ? winston.format.combine(
            winston.format.colorize(),
            formats.pretty
          )
        : formats.json
    }),
    // Error log file
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 5
    }),
    // Combined log file
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 10485760, // 10MB
      maxFiles: 10
    })
  ]
});

// Add stream for Morgan HTTP logging
logger.stream = {
  write: (message) => logger.info(message.trim())
};

module.exports = logger;
