/*
 *------------------------------------------------------------
 *                                  ___ ___ _   
 *  ___ ___ ___ ___ ___       _____|  _| . | |_ 
 * |  _| . |_ -|  _| . |     |     | . | . | '_|
 * |_| |___|___|___|___|_____|_|_|_|___|___|_,_| 
 *                     |_____|       firmware v1                 
 * ------------------------------------------------------------
 * Copyright (c)2019 Ross Bamford
 * See top-level LICENSE.md for licence information.
 *
 * C prototypes for routines implemented in assembly.
 * ------------------------------------------------------------
 */

/* 
 * Idle the processor.
 *
 * Issues a STOP instruction, keeping the CPU in supervisor mode
 * and setting interrupt priority to 3.
 *
 * Requires the CPU to be in supervisor mode.
 */
noreturn void IDLE();

/*
 * Halt the processor.
 *
 * Issues a STOP instruction, keeping the CPU in supervisor mode
 * and masking all interrupts (priority to 7).
 *
 * The only way to come back from this is via the wetware!
 *
 * Requires the CPU to be in supervisor mode.
 */
noreturn void HALT();

/*
 * Set m68k interrupt priority level (0-7).
 *
 * Requires the CPU to be in supervisor mode.
 */
void SET_INTR(uint8_t priority);

